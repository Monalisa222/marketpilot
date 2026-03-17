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
                {
                  external_id: normalize_id(variant["id"]),
                  sku: variant["sku"],
                  price: variant["price"].to_f
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
    end
  end
end
