class InventorySyncService
  def initialize(variant)
    @variant = variant
  end

  def sync
    @variant.listings.each do |listing|
      listing.update!(quantity: @variant.quantity)
      adapter = MarketplaceAdapterResolver.for(listing.marketplace_account)

      adapter.update_inventory(
        listing.external_id,
        listing.quantity
      )

      SyncLoggerService.log(
        organization: listing.marketplace_account.organization,
        resource: listing,
        action: "inventory_sync",
        status: "success",
        message: "Inventory updated to #{listing.quantity}"
      )
    rescue StandardError => e
      SyncLoggerService.log(
        organization: listing.marketplace_account.organization,
        resource: listing,
        action: "inventory_sync",
        status: "failure",
        message: e.message
      )
    end
  end
end
