require "net/http"
require "json"

module Integrations
  module Shopify
    class GraphqlClient
      API_VERSION = "2026-01"

      def initialize(account)
        @account = account
      end

      def call(query, variables = {})
        uri = URI("https://#{@account.credential(:shop_domain)}/admin/api/#{API_VERSION}/graphql.json")

        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request["X-Shopify-Access-Token"] = @account.credential(:access_token)
        request.body = { query: query, variables: variables }.to_json

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        body = JSON.parse(response.body)
        raise "Shopify Error: #{body['errors']}" if body["errors"]

        body["data"]
      end
    end
  end
end
