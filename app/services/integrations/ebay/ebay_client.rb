require "net/http"
require "json"

module Integrations
  module Ebay
    class EbayClient
      BASE_URL = "https://api.sandbox.ebay.com"

      def initialize(account)
        @account = account
      end

      def get(path)
        request(:get, path)
      end

      def post(path, body = {})
        request(:post, path, body)
      end

      def put(path, body = {})
        request(:put, path, body)
      end

      private

      def request(method, path, body = {})
        uri = URI("#{BASE_URL}#{path}")

        req_class = Net::HTTP.const_get(method.to_s.capitalize)
        request = req_class.new(uri)

        request["Authorization"] = "Bearer #{access_token}"
        request["Content-Type"] = "application/json"
        request["Content-Language"] = "en-US"
        request["Accept"] = "application/json"

        request.body = body.to_json if body.present?

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        # 🔥 retry on token expiry
        if response.code.to_i == 401
          refresh_token!
          request["Authorization"] = "Bearer #{access_token}"
          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
        end

        handle_response(response)
      rescue => e
        Rails.logger.error("eBay API ERROR: #{e.message}")
        {}
      end

      def handle_response(response)
        return {} if response.code.to_i == 204 || response.body.blank?

        JSON.parse(response.body) rescue {}
      end

      def access_token
        if token_expired?
          refresh_token!
        end

        @account.credentials["access_token"]
      end

      def token_expired?
        expires_at = @account.credentials["expires_at"]
        expires_at.blank? || Time.current >= expires_at
      end

      def refresh_token!
        Integrations::Ebay::RefreshTokenService.new(@account).call
        @account.reload
      end
    end
  end
end
