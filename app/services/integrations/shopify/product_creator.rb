module Integrations
  module Shopify
    class ProductCreator < BaseService
      def initialize(product, account)
        super(account: account, resource: product)

        @product = product
        @account = account
        @client = GraphqlClient.new(account)
      end

      def call
        if already_pushed?
          log_success("shopify_product_skip", "Product already pushed")
          return
        end

        product = create_product
        create_variants(product["id"])

        log_success("shopify_product_create", "Created #{product['id']}")

        product
      rescue => e
        log_failure("shopify_product_create", e.message)
        raise e
      end

      private

      # --------------------------------
      # IDEMPOTENCY (FIXED)
      # --------------------------------
      def already_pushed?
        @product.variants.joins(:listings)
                .where(listings: { marketplace_account_id: @account.id })
                .exists?
      end

      # --------------------------------
      # CREATE PRODUCT
      # --------------------------------
      def create_product
        data = @client.call(product_mutation, product_variables)

        errors = data.dig("productCreate", "userErrors")
        raise "Product Create Error: #{errors}" if errors.present?

        data.dig("productCreate", "product")
      end

      def product_mutation
        <<~GRAPHQL
        mutation($input: ProductInput!) {
          productCreate(input: $input) {
            product {
              id
              title
            }
            userErrors {
              field
              message
            }
          }
        }
        GRAPHQL
      end

      def product_variables
        {
          input: {
            title: @product.title
          }
        }
      end

      # --------------------------------
      # HANDLE VARIANTS
      # --------------------------------
      def create_variants(product_gid)
        return if @product.variants.blank?

        variant_gid, inventory_item_id = fetch_default_variant_data(product_gid)

        first_variant = @product.variants.first

        update_default_variant(product_gid, variant_gid, first_variant)

        # 🔥 IMPORTANT FIX FLOW
        activate_inventory_if_needed(inventory_item_id)
        adjust_inventory(inventory_item_id, first_variant.quantity || 0)

        # Remaining variants
        remaining_variants = @product.variants.drop(1)
        return if remaining_variants.blank?

        data = @client.call(
          variant_mutation,
          variant_variables(product_gid, remaining_variants)
        )

        errors = data.dig("productVariantsBulkCreate", "userErrors")
        raise "Variant Create Error: #{errors}" if errors.present?

        create_listings_for_new_variants(data, remaining_variants)
      end

      # --------------------------------
      # FETCH DEFAULT VARIANT
      # --------------------------------
      def fetch_default_variant_data(product_gid)
        data = @client.call(<<~GRAPHQL, { id: product_gid })
        query($id: ID!) {
          product(id: $id) {
            variants(first: 1) {
              nodes {
                id
                inventoryItem {
                  id
                }
              }
            }
          }
        }
        GRAPHQL

        node = data.dig("product", "variants", "nodes", 0)
        [ node["id"], node.dig("inventoryItem", "id") ]
      end

      # --------------------------------
      # UPDATE DEFAULT VARIANT
      # --------------------------------
      def update_default_variant(product_gid, variant_gid, variant)
        query = <<~GRAPHQL
        mutation($productId: ID!, $variants: [ProductVariantsBulkInput!]!) {
          productVariantsBulkUpdate(productId: $productId, variants: $variants) {
            userErrors {
              field
              message
            }
          }
        }
        GRAPHQL

        variables = {
          productId: product_gid,
          variants: [
            {
              id: variant_gid,
              price: variant.price.to_s,
              inventoryItem: {
                sku: variant.sku || "SKU-#{variant.id}",
                tracked: true
              }
            }
          ]
        }

        data = @client.call(query, variables)

        errors = data.dig("productVariantsBulkUpdate", "userErrors")
        raise "Default Variant Update Error: #{errors}" if errors.present?

        create_listing(variant, variant_gid)
      end

      # --------------------------------
      # CREATE REMAINING VARIANTS
      # --------------------------------
      def variant_mutation
        <<~GRAPHQL
        mutation($productId: ID!, $variants: [ProductVariantsBulkInput!]!) {
          productVariantsBulkCreate(productId: $productId, variants: $variants) {
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
      end

      def variant_variables(product_gid, variants)
        {
          productId: product_gid,
          variants: variants.map do |variant|
            {
              price: variant.price.to_s,
              inventoryItem: {
                sku: variant.sku || "SKU-#{variant.id}",
                tracked: true
              },
              inventoryQuantities: [
                {
                  availableQuantity: variant.quantity || 0,
                  locationId: default_location_gid
                }
              ]
            }
          end
        }
      end

      # --------------------------------
      # INVENTORY LOCATION HELPERS
      # --------------------------------
      def fetch_inventory_location(inventory_item_id)
        data = @client.call(<<~GRAPHQL, { id: inventory_item_id })
        query($id: ID!) {
          inventoryItem(id: $id) {
            inventoryLevels(first: 1) {
              nodes {
                location {
                  id
                }
              }
            }
          }
        }
        GRAPHQL

        data.dig("inventoryItem", "inventoryLevels", "nodes", 0, "location", "id")
      end

      def activate_inventory_if_needed(inventory_item_id)
        existing_location = fetch_inventory_location(inventory_item_id)
        return if existing_location.present?  # ✅ already linked

        query = <<~GRAPHQL
        mutation($inventoryItemId: ID!, $locationId: ID!) {
          inventoryActivate(inventoryItemId: $inventoryItemId, locationId: $locationId) {
            userErrors {
              message
            }
          }
        }
        GRAPHQL

        variables = {
          inventoryItemId: inventory_item_id,
          locationId: default_location_gid
        }

        @client.call(query, variables)
      end

      # --------------------------------
      # INVENTORY ADJUST (FIXED)
      # --------------------------------
      def adjust_inventory(inventory_item_id, quantity)
        location_id = fetch_inventory_location(inventory_item_id) || default_location_gid

        query = <<~GRAPHQL
        mutation($input: InventoryAdjustQuantitiesInput!) {
          inventoryAdjustQuantities(input: $input) {
            userErrors {
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
                inventoryItemId: inventory_item_id,
                locationId: location_id,
                delta: quantity
              }
            ]
          }
        }

        3.times do
          response = @client.call(query, variables)
          errors = response.dig("inventoryAdjustQuantities", "userErrors")

          return if errors.blank?

          sleep 1
        end

        raise "Inventory update failed"
      end

      # --------------------------------
      # LISTINGS
      # --------------------------------
      def create_listing(variant, gid)
        Listing.create!(
          marketplace_account_id: @account.id,
          variant: variant,
          external_id: extract_id(gid)
        )
      end

      def create_listings_for_new_variants(data, variants)
        shopify_variants = data.dig("productVariantsBulkCreate", "productVariants")

        variants.each_with_index do |variant, index|
          gid = shopify_variants[index]["id"]
          create_listing(variant, gid)
        end
      end

      def extract_id(gid)
        gid.split("/").last
      end

      # --------------------------------
      # LOCATION
      # --------------------------------
      def default_location_gid
        @default_location_gid ||= fetch_location_gid
      end

      def fetch_location_gid
        data = @client.call(<<~GRAPHQL)
        {
          locations(first: 1) {
            nodes { id }
          }
        }
        GRAPHQL

        data.dig("locations", "nodes", 0, "id")
      end
    end
  end
end
