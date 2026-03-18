module Integrations
  module Shopify
    class ProductFetcher
      PAGE_SIZE = 50

      def initialize(account)
        @client = GraphqlClient.new(account)
      end

      def call
        products = []
        cursor = nil

        loop do
          data = @client.call(query, { cursor: cursor })

          data["products"]["nodes"].each do |product|
            products << build_product(product)
          end

          page_info = data["products"]["pageInfo"]
          break unless page_info["hasNextPage"]

          cursor = page_info["endCursor"]
        end

        products
      end

      private

      def query
        <<~GRAPHQL
        query($cursor: String) {
          products(first: #{PAGE_SIZE}, after: $cursor) {
            pageInfo { hasNextPage endCursor }
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
      end

      def build_product(product)
        {
          external_id: Helpers.normalize_id(product["id"]),
          title: product["title"],
          variants: product.dig("variants", "nodes").map { |v| build_variant(v) }
        }
      end

      def build_variant(variant)
        quantity =
          variant.dig("inventoryItem", "inventoryLevels", "nodes")&.first
                 &.dig("quantities")
                 &.find { |q| q["name"] == "available" }
                 &.dig("quantity") || 0

        {
          external_id: Helpers.normalize_id(variant["id"]),
          sku: variant["sku"],
          price: variant["price"].to_f,
          quantity: quantity
        }
      end
    end
  end
end
