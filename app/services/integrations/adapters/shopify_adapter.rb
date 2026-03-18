module Integrations
  module Adapters
    class ShopifyAdapter < BaseAdapter
      def fetch_orders
        Shopify::OrderFetcher.new(@account).call
      end

      def fetch_products
        Shopify::ProductFetcher.new(@account).call
      end

      def update_price(external_variant_id, price)
        Shopify::PriceUpdater.new(@account, external_variant_id, price).call
      end

      def update_inventory(external_variant_id, quantity)
        Shopify::InventoryUpdater.new(@account, external_variant_id, quantity).call
      end
    end
  end
end
