class MarketplaceAdapterResolver
  def self.for(account)
    case account.marketplace

    when "shopify"
      Integrations::Adapters::ShopifyAdapter.new(account)
    when "ebay"
      Integrations::Adapters::EbayAdapter.new(account)

    else
      raise "Unsupported marketplace"
    end
  end
end
