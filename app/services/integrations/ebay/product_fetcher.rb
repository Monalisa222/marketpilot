module Integrations
  module Ebay
    class ProductFetcher
      PAGE_SIZE = 50

      def initialize(account)
        @client = Integrations::Ebay::EbayClient.new(account)
      end

      def call
        products = []
        offset = 0

        loop do
          data = @client.get("/sell/inventory/v1/inventory_item?limit=#{PAGE_SIZE}&offset=#{offset}")
          items = data["inventoryItems"] || []
          break if items.empty?

          items.each do |item|
            products << build_product(item)
          end

          offset += PAGE_SIZE
        end

        products
      rescue => e
        Rails.logger.error("Ebay Product Fetch Error: #{e.message}")
        []
      end

      private

      def build_product(item)
        sku = item["sku"]

        {
          external_id: sku, # eBay has no product id
          title: item.dig("product", "title"),
          variants: [ build_variant(item) ]
        }
      end

      def build_variant(item)
        sku = item["sku"]

        {
          external_id: sku, # important for Listing mapping
          sku: sku,
          price: fetch_price(sku),
          quantity: item.dig("availability", "shipToLocationAvailability", "quantity") || 0
        }
      end

      def fetch_price(sku)
        data = @client.get("/sell/inventory/v1/offer?sku=#{sku}")
        offer = data["offers"]&.first

        offer.dig("pricingSummary", "price", "value").to_f
      rescue
        0.0
      end
    end
  end
end
