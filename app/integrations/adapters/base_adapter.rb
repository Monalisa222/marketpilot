module Integrations
  module Adapters
    class BaseAdapter
      def initialize(account)
        @account = account
        @client = MarketplaceApiClient.new(account)
      end

      def fetch_products
        raise NotImplementedError
      end

      def fetch_orders
        raise NotImplementedError
      end

      def update_inventory(sku, quantity)
        raise NotImplementedError
      end

      def update_price(sku, price)
        raise NotImplementedError
      end
    end
  end
end
