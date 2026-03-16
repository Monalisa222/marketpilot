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

      SyncLoggerService.log(
        organization: listing.marketplace_account.organization,
        resource: listing,
        action: "price_sync",
        status: "success",
        message: "Price updated to #{listing.price}"
      )
    rescue StandardError => e
      SyncLoggerService.log(
        organization: listing.marketplace_account.organization,
        resource: listing,
        action: "price_sync",
        status: "failure",
        message: e.message
      )
    end
  end
end
