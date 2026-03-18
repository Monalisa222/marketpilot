module Webhooks
  class ShopifyController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :verify_shopify_hmac!

    def orders_create
      account = find_account!

      OrderImportJob.perform_later(account.id)

      head :ok
    rescue => e
      Rails.logger.error("[Webhook][Orders] #{e.message}")
      head :internal_server_error
    end

    def products_update
      account = find_account!

      MarketplaceSyncJob.perform_later(account.id, "products")

      head :ok
    rescue => e
      Rails.logger.error("[Webhook][Products] #{e.message}")
      head :internal_server_error
    end

    private

    # Verify Shopify webhook authenticity
    def verify_shopify_hmac!
      hmac_header = request.headers["X-Shopify-Hmac-Sha256"]
      data = request.body.read

      digest = OpenSSL::Digest.new("sha256")

      calculated_hmac = Base64.strict_encode64(
        OpenSSL::HMAC.digest(digest, shopify_secret, data)
      )

      unless ActiveSupport::SecurityUtils.secure_compare(calculated_hmac, hmac_header)
        Rails.logger.warn("Invalid Shopify webhook HMAC")
        head :unauthorized
      end

      request.body.rewind
    end

    def find_account!
      shop_domain = request.headers["X-Shopify-Shop-Domain"]

      account = MarketplaceAccount
                  .where(marketplace: "shopify")
                  .where("credentials ->> 'shop_domain' = ?", shop_domain)
                  .first

      raise "Account not found for #{shop_domain}" unless account

      account
    end

    def shopify_secret
      ENV["SHOPIFY_WEBHOOK_SECRET"]
    end
  end
end
