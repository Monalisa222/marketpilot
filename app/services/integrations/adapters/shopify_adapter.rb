module Integrations
  module Adapters
    class ShopifyAdapter < BaseAdapter
      def fetch_orders
        Shopify::OrderFetcher.new(@account).call
      rescue
        []
      end

      def fetch_products
        Shopify::ProductFetcher.new(@account).call
      rescue
        []
      end

      def update_price(listing, price)
        Shopify::PriceUpdater.new(@account, listing.external_id, price).call

        {
          success: true,
          message: "Price updated",
          external_id: listing.external_id
        }
      rescue => e
        {
          success: false,
          error: e.message,
          external_id: listing.external_id
        }
      end

      def update_inventory(listing, quantity)
        Shopify::InventoryUpdater.new(@account, listing.external_id, quantity).call

        {
          success: true,
          message: "Inventory updated",
          external_id: listing.external_id
        }
      rescue => e
        {
          success: false,
          error: e.message,
          external_id: listing.external_id
        }
      end
    end
  end
end
