class PriceSyncService < BaseService
  def initialize(variant)
    @variant = variant

    # initialize with safe defaults
    super(account: nil, resource: nil)
  end

  def sync
    @variant.listings.each do |listing|
      @account = listing.marketplace_account
      @resource = listing

      listing.update!(price: @variant.price)

      adapter = MarketplaceAdapterResolver.for(listing.marketplace_account)

      result = adapter.update_price(listing, listing.price)

      if result[:success]
        log_success("price_sync", "Updated to #{listing.price}")
      else
        log_failure("price_sync", result[:error])
      end

    rescue => e
      log_failure("price_sync", e.message)
    end
  end
end
