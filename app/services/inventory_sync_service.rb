class InventorySyncService < BaseService
  def initialize(variant)
    @variant = variant

    # initialize with safe defaults
    super(account: nil, resource: nil)
  end

  def sync
    @variant.listings.find_each do |listing|
      # set correct context per listing
      @account = listing.marketplace_account
      @resource = listing

      listing.update!(quantity: @variant.quantity)

      adapter = MarketplaceAdapterResolver.for(@account)

      result = adapter.update_inventory(listing, listing.quantity)

      if result[:success]
        log_success("inventory_sync", "Updated to #{listing.quantity}")
      else
        log_failure("inventory_sync", result[:error])
      end

    rescue => e
      log_failure("inventory_sync", e.message)
    ensure
      @resource = nil
    end
  end
end
