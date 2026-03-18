require "net/http"
require "json"

module Integrations
  module Adapters
    class ShopifyAdapter < BaseAdapter
      API_VERSION = "2026-01"
      PAGE_SIZE = 50

      # --------------------------------
      # GraphQL Client
      # --------------------------------
      def graphql_query(query, variables = {})
        uri = URI("https://#{@account.credential(:shop_domain)}/admin/api/#{API_VERSION}/graphql.json")

        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request["X-Shopify-Access-Token"] = @account.credential(:access_token)

        request.body = { query: query, variables: variables }.to_json

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        body = JSON.parse(response.body)
        raise "Shopify Error: #{body['errors']}" if body["errors"]

        body["data"]
      end

      # --------------------------------
      # Normalize GID
      # --------------------------------
      def normalize_id(gid)
        gid.split("/").last
      end

      # --------------------------------
      # Fetch ALL Orders (Paginated)
      # --------------------------------
      def fetch_orders
        orders = []
        cursor = nil

        loop do
          query = <<~GRAPHQL
          query($cursor: String) {
            orders(first: #{PAGE_SIZE}, after: $cursor) {
              pageInfo {
                hasNextPage
                endCursor
              }
              nodes {
                id
                name
                displayFinancialStatus
                currentTotalPriceSet {
                  shopMoney {
                    amount
                  }
                }
                lineItems(first: 50) {
                  nodes {
                    sku
                    quantity
                    originalUnitPriceSet {
                      shopMoney {
                        amount
                      }
                    }
                    variant {
                      id
                    }
                  }
                }
              }
            }
          }
          GRAPHQL

          data = graphql_query(query, { cursor: cursor })

          batch = data["orders"]["nodes"]

          batch.each do |order|
            orders << {
              external_id: normalize_id(order["id"]),
              name: order["name"],
              status: order["displayFinancialStatus"],
              total_price: order["currentTotalPriceSet"]["shopMoney"]["amount"].to_f,
              items: order["lineItems"]["nodes"].map do |item|
                {
                  external_variant_id: item.dig("variant", "id")&.split("/")&.last,
                  sku: item["sku"],
                  quantity: item["quantity"],
                  price: item["originalUnitPriceSet"]["shopMoney"]["amount"].to_f
                }
              end
            }
          end

          page_info = data["orders"]["pageInfo"]
          break unless page_info["hasNextPage"]

          cursor = page_info["endCursor"]
        end

        orders
      end

      # --------------------------------
      # Fetch ALL Products (Paginated)
      # --------------------------------
      def fetch_products
        products = []
        cursor = nil

        loop do
          query = <<~GRAPHQL
          query($cursor: String) {
            products(first: #{PAGE_SIZE}, after: $cursor) {
              pageInfo {
                hasNextPage
                endCursor
              }
              nodes {
                id
                title
                variants(first: 50) {
                  nodes {
                    id
                    sku
                    price
                    inventoryItem {
                      inventoryLevels(first: 1) {
                        nodes {
                          quantities(names: ["available"]) {
                            name
                            quantity
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
          GRAPHQL

          data = graphql_query(query, { cursor: cursor })

          batch = data["products"]["nodes"]

          batch.each do |product|
            products << {
              external_id: normalize_id(product["id"]),
              title: product["title"],
              variants: product["variants"]["nodes"].map do |variant|
                levels = variant.dig("inventoryItem", "inventoryLevels", "nodes") || []

                quantity =
                  levels.first&.dig("quantities")&.find { |q| q["name"] == "available" }&.dig("quantity") || 0

                {
                  external_id: normalize_id(variant["id"]),
                  sku: variant["sku"],
                  price: variant["price"].to_f,
                  quantity: quantity
                }
              end
            }
          end

          page_info = data["products"]["pageInfo"]
          break unless page_info["hasNextPage"]

          cursor = page_info["endCursor"]
        end

        products
      end

      # --------------------------------
      # Update Price
      # --------------------------------

      def update_price(external_variant_id, price)
        gid = "gid://shopify/ProductVariant/#{external_variant_id}"

        query = <<~GRAPHQL
        mutation($productId: ID!, $variants: [ProductVariantsBulkInput!]!) {
          productVariantsBulkUpdate(productId: $productId, variants: $variants) {
            productVariants {
              id
              price
            }
            userErrors {
              field
              message
            }
          }
        }
        GRAPHQL

        # Shopify requires productId also
        product_gid = get_product_gid_from_variant(gid)

        variables = {
          productId: product_gid,
          variants: [
            {
              id: gid,
              price: price.to_s
            }
          ]
        }

        data = graphql_query(query, variables)

        errors = data.dig("productVariantsBulkUpdate", "userErrors")

        if errors.present?
          SyncLoggerService.log(
            organization: @account.organization,
            resource: @account,
            action: "shopify_price_update",
            status: "failed",
            message: "Variant #{external_variant_id} failed: #{errors}"
          )

          raise "Shopify Price Update Error: #{errors}"
        end

        SyncLoggerService.log(
          organization: @account.organization,
          resource: @account,
          action: "shopify_price_update",
          status: "success",
          message: "Variant #{external_variant_id} updated to price #{price}"
        )

        data["productVariantsBulkUpdate"]["productVariants"]

      rescue => e
        SyncLoggerService.log(
          organization: @account.organization,
          resource: @account,
          action: "shopify_price_update",
          status: "failed",
          message: e.message
        )

        raise e
      end

      # --------------------------------
      # Update Inventory
      # --------------------------------
      def update_inventory(external_variant_id, new_quantity)
        variant_gid = "gid://shopify/ProductVariant/#{external_variant_id}"

        # 1. Get inventoryItemId
        inventory_item_gid = get_inventory_item_gid(variant_gid)

        # 2. Get locationId
        location_gid = get_inventory_location_gid(inventory_item_gid)

        unless location_gid
          SyncLoggerService.log(
            organization: @account.organization,
            resource: @account,
            action: "shopify_inventory_update",
            status: "failed",
            message: "No inventory location found for variant #{external_variant_id}"
          )
          return
        end

        # 3. Get current quantity from Shopify
        current_quantity = get_current_inventory(inventory_item_gid, location_gid)

        # 4. Calculate delta
        delta = new_quantity - current_quantity

        # No change needed
        if delta == 0
          SyncLoggerService.log(
            organization: @account.organization,
            resource: @account,
            action: "shopify_inventory_update",
            status: "skipped",
            message: "Variant #{external_variant_id} already at #{new_quantity}"
          )
          return
        end

        # 5. Apply delta
        query = <<~GRAPHQL
        mutation($input: InventoryAdjustQuantitiesInput!) {
          inventoryAdjustQuantities(input: $input) {
            userErrors {
              field
              message
            }
          }
        }
        GRAPHQL

        variables = {
          input: {
            reason: "correction",
            name: "available",
            changes: [
              {
                inventoryItemId: inventory_item_gid,
                locationId: location_gid,
                delta: delta
              }
            ]
          }
        }

        data = graphql_query(query, variables)

        errors = data.dig("inventoryAdjustQuantities", "userErrors")

        if errors.present?
          SyncLoggerService.log(
            organization: @account.organization,
            resource: @account,
            action: "shopify_inventory_update",
            status: "failed",
            message: "Variant #{external_variant_id} failed: #{errors}"
          )
          raise "Shopify Inventory Error: #{errors}"
        end

        SyncLoggerService.log(
          organization: @account.organization,
          resource: @account,
          action: "shopify_inventory_update",
          status: "success",
          message: "Variant #{external_variant_id}: #{current_quantity} → #{new_quantity} (delta #{delta})"
        )

      rescue => e
        SyncLoggerService.log(
          organization: @account.organization,
          resource: @account,
          action: "shopify_inventory_update",
          status: "failed",
          message: e.message
        )
        raise e
      end

      # --------------------------------
      # Helper to get Product GID from Variant GID
      # --------------------------------
      def get_product_gid_from_variant(variant_gid)
        query = <<~GRAPHQL
        query($id: ID!) {
          productVariant(id: $id) {
            product {
              id
            }
          }
        }
        GRAPHQL

        data = graphql_query(query, { id: variant_gid })

        data.dig("productVariant", "product", "id")
      end

      def get_inventory_item_gid(variant_gid)
        query = <<~GRAPHQL
        query($id: ID!) {
          productVariant(id: $id) {
            inventoryItem {
              id
            }
          }
        }
        GRAPHQL

        data = graphql_query(query, { id: variant_gid })

        data.dig("productVariant", "inventoryItem", "id")
      end

      def get_current_inventory(inventory_item_gid, location_gid)
        query = <<~GRAPHQL
        query($inventoryItemId: ID!) {
          inventoryItem(id: $inventoryItemId) {
            inventoryLevels(first: 10) {
              nodes {
                location {
                  id
                }
                quantities(names: ["available"]) {
                  name
                  quantity
                }
              }
            }
          }
        }
        GRAPHQL

        data = graphql_query(query, { inventoryItemId: inventory_item_gid })

        levels = data.dig("inventoryItem", "inventoryLevels", "nodes") || []

        level = levels.find { |l| l.dig("location", "id") == location_gid }

        level&.dig("quantities")&.find { |q| q["name"] == "available" }&.dig("quantity") || 0
      end

      def get_inventory_location_gid(inventory_item_gid)
        query = <<~GRAPHQL
        query($inventoryItemId: ID!) {
          inventoryItem(id: $inventoryItemId) {
            inventoryLevels(first: 10) {
              nodes {
                location {
                  id
                }
              }
            }
          }
        }
        GRAPHQL

        data = graphql_query(query, { inventoryItemId: inventory_item_gid })

        levels = data.dig("inventoryItem", "inventoryLevels", "nodes") || []

        # 👉 return first valid location where item exists
        levels.first&.dig("location", "id")
      end
    end
  end
end
