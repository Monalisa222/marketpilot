class InventorySyncService
  def initialize(variant)
    @variant = variant
  end

  def sync
    @variant.listings.each do |listing|
      adapter = MarketplaceAdapterResolver.for(listing.marketplace_account)

      adapter.update_inventory(
        @variant.sku,
        @variant.quantity
      )
    end
  end
end
