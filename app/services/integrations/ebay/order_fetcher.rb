module Integrations
  module Ebay
    class OrderFetcher
      PAGE_SIZE = 50

      def initialize(account)
        @client = Integrations::Ebay::EbayClient.new(account)
      end

      def call
        orders = []
        offset = 0

        loop do
          data = @client.get("/sell/fulfillment/v1/order?limit=#{PAGE_SIZE}&offset=#{offset}")
          raw_orders = data["orders"] || []
          break if raw_orders.empty?

          raw_orders.each do |order|
            orders << build_order(order)
          end

          offset += PAGE_SIZE
        end

        orders
      rescue => e
        Rails.logger.error("Ebay Order Fetch Error: #{e.message}")
        []
      end

      private

      def build_order(order)
        {
          external_id: order["orderId"],
          status: order["orderFulfillmentStatus"],
          total_price: order.dig("pricingSummary", "total", "value").to_f,
          items: (order["lineItems"] || []).map { |i| build_item(i) }
        }
      end

      def build_item(item)
        {
          external_variant_id: item["sku"], # MUST match Product external_id
          sku: item["sku"],
          quantity: item["quantity"],
          price: item.dig("lineItemCost", "value").to_f
        }
      end
    end
  end
end
