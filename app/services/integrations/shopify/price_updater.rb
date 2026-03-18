module Integrations
  module Shopify
    class PriceUpdater
      def initialize(account, external_variant_id, price)
        @client = GraphqlClient.new(account)
        @account = account
        @variant_gid = Helpers.gid("ProductVariant", external_variant_id)
        @price = price
      end

      def call
        product_gid = get_product_gid

        data = @client.call(mutation, variables(product_gid))

        errors = data.dig("productVariantsBulkUpdate", "userErrors")

        if errors.present?
          log_failure(errors)
          raise "Shopify Price Error: #{errors}"
        end

        log_success
        data["productVariantsBulkUpdate"]["productVariants"]

      rescue => e
        log_failure(e.message)
        raise e
      end

      private

      def mutation
        <<~GRAPHQL
        mutation($productId: ID!, $variants: [ProductVariantsBulkInput!]!) {
          productVariantsBulkUpdate(productId: $productId, variants: $variants) {
            productVariants { id price }
            userErrors { field message }
          }
        }
        GRAPHQL
      end

      def variables(product_gid)
        {
          productId: product_gid,
          variants: [ {
            id: @variant_gid,
            price: @price.to_s
          } ]
        }
      end

      def get_product_gid
        data = @client.call(<<~GRAPHQL, { id: @variant_gid })
        query($id: ID!) {
          productVariant(id: $id) {
            product { id }
          }
        }
        GRAPHQL

        data.dig("productVariant", "product", "id")
      end

      def log_success
        SyncLoggerService.log(
          organization: @account.organization,
          resource: @account,
          action: "shopify_price_update",
          status: "success",
          message: "Price updated to #{@price}"
        )
      end

      def log_failure(msg)
        SyncLoggerService.log(
          organization: @account.organization,
          resource: @account,
          action: "shopify_price_update",
          status: "failed",
          message: msg
        )
      end
    end
  end
end
