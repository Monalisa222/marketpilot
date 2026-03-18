module Integrations
  module Shopify
    module Helpers
      def self.normalize_id(gid)
        gid&.split("/")&.last
      end

      def self.gid(type, id)
        "gid://shopify/#{type}/#{id}"
      end
    end
  end
end
