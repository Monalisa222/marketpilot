module Integrations
  module Ebay
    class ProductCreator < BaseService
      def initialize(product, account)
        super(account: account, resource: product)

        @product = product
        @account = account
        @adapter = Integrations::Adapters::EbayAdapter.new(account)
      end

      def call
        if already_pushed?
          log_success("ebay_product_skip", "Already pushed")
          return
        end

        @adapter.create_product(@product)

        log_success("ebay_product_create", "Created product")
      rescue => e
        log_failure("ebay_product_create", e.message)
        raise e
      end

      private

      def already_pushed?
        @product.variants.all? do |variant|
          variant.listings.exists?(marketplace_account_id: @account.id)
        end
      end
    end
  end
end
