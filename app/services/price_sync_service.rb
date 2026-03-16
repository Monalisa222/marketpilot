class PriceSyncService
  def initialize(variant)
    @variant = variant
  end

  def sync
    @variant.listings.each do |listing|
      adapter = MarketplaceAdapterResolver.for(listing.marketplace_account)

      adapter.update_price(
        @variant.sku,
        listing.price
      )
    end
  end
end
