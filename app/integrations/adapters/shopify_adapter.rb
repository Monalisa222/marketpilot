module Integrations
  module Adapters
    class ShopifyAdapter < BaseAdapter

      def fetch_products
        # Shopify product API call will go here
      end

      def fetch_orders
        # Shopify order API call will go here
      end

      def update_inventory(sku, quantity)
        # Shopify inventory API
      end

      def update_price(sku, price)
        # Shopify price update
      end

    end
  end
end
