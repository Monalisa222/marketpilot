module Integrations
  module Shopify
    class OrderFetcher
      PAGE_SIZE = 50

      def initialize(account)
        @client = GraphqlClient.new(account)
      end

      def call
        orders = []
        cursor = nil

        loop do
          data = @client.call(query, { cursor: cursor })

          data["orders"]["nodes"].each do |order|
            orders << build_order(order)
          end

          page_info = data["orders"]["pageInfo"]
          break unless page_info["hasNextPage"]

          cursor = page_info["endCursor"]
        end

        orders
      end

      private

      def query
        <<~GRAPHQL
        query($cursor: String) {
          orders(first: #{PAGE_SIZE}, after: $cursor) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id
              name
              displayFinancialStatus
              currentTotalPriceSet { shopMoney { amount } }
              lineItems(first: 50) {
                nodes {
                  sku
                  quantity
                  originalUnitPriceSet { shopMoney { amount } }
                  variant { id }
                }
              }
            }
          }
        }
        GRAPHQL
      end

      def build_order(order)
        {
          external_id: Helpers.normalize_id(order["id"]),
          name: order["name"],
          status: order["displayFinancialStatus"],
          total_price: order.dig("currentTotalPriceSet", "shopMoney", "amount").to_f,
          items: order.dig("lineItems", "nodes").map { |i| build_item(i) }
        }
      end

      def build_item(item)
        {
          external_variant_id: Helpers.normalize_id(item.dig("variant", "id")),
          sku: item["sku"],
          quantity: item["quantity"],
          price: item.dig("originalUnitPriceSet", "shopMoney", "amount").to_f
        }
      end
    end
  end
end
