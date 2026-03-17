class RepricingService
  def initialize(listing)
    @listing = listing
    @rule = listing.repricing_rule
  end

  def run
    return unless @rule

    competitor_price = fetch_competitor_price

    new_price = PriceCalculatorService
                  .new(@listing, competitor_price)
                  .calculate

    return if new_price == @listing.price

    @listing.update!(price: new_price)

    adapter = MarketplaceAdapterResolver.for(
      @listing.marketplace_account
    )

    adapter.update_price(
      @listing.external_id,
      new_price
    )

    SyncLoggerService.log(
      organization: @listing.marketplace_account.organization,
      resource: @listing,
      action: "repricing",
      status: "success"
    )

  rescue => e
    SyncLoggerService.log(
      organization: @listing.marketplace_account.organization,
      resource: @listing,
      action: "repricing",
      status: "failed",
      message: e.message
    )
  end

  private

  def fetch_competitor_price
    # placeholder (can integrate later)
    @listing.price
  end
end
