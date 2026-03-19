require "net/http"
require "json"
require "base64"

module Integrations
  module Ebay
    class TokenService
      TOKEN_URL = "https://api.sandbox.ebay.com/identity/v1/oauth2/token"

      def initialize(account)
        @account = account
      end

      def call
        Rails.cache.fetch(cache_key, expires_in: 2.hours) do
          fetch_token
        end
      end

      private

      def fetch_token
        uri = URI(TOKEN_URL)

        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/x-www-form-urlencoded"
        request["Authorization"] = "Basic #{encoded_credentials}"

        request.body = URI.encode_www_form(
          grant_type: "client_credentials",
          scope: "https://api.ebay.com/oauth/api_scope"
        )

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        JSON.parse(response.body)["access_token"]
      end

      def encoded_credentials
        Base64.strict_encode64("#{client_id}:#{client_secret}")
      end

      def client_id
        @account.credential(:client_id)
      end

      def client_secret
        @account.credential(:client_secret)
      end

      def cache_key
        "ebay_token_#{@account.id}"
      end
    end
  end
end
