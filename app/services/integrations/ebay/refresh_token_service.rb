require "net/http"
require "json"
require "base64"

module Integrations
  module Ebay
    class RefreshTokenService
      TOKEN_URL = "https://api.sandbox.ebay.com/identity/v1/oauth2/token"

      def initialize(account)
        @account = account
      end

      def call
        uri = URI(TOKEN_URL)

        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/x-www-form-urlencoded"
        request["Authorization"] = "Basic #{encoded_credentials}"

        request.body = URI.encode_www_form(
          grant_type: "refresh_token",
          refresh_token: refresh_token,
          scope: scopes
        )

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        parsed = JSON.parse(response.body) rescue {}

        token = parsed["access_token"]
        expires_in = parsed["expires_in"]

        return unless token.present?

        creds = @account.credentials || {}
        creds["access_token"] = token
        creds["expires_at"] = Time.current + expires_in.to_i.seconds

        @account.update!(credentials: creds)

        token
      rescue => e
        Rails.logger.error("eBay refresh error: #{e.message}")
        nil
      end

      private

      def encoded_credentials
        Base64.strict_encode64("#{ENV['EBAY_CLIENT_ID']}:#{ENV['EBAY_CLIENT_SECRET']}")
      end

      def refresh_token
        @account.credentials["refresh_token"]
      end

      def scopes
        [
          "https://api.ebay.com/oauth/api_scope",
          "https://api.ebay.com/oauth/api_scope/sell.inventory",
          "https://api.ebay.com/oauth/api_scope/sell.fulfillment"
        ].join(" ")
      end
    end
  end
end
