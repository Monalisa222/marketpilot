class RepricingService < BaseService
  def initialize(listing)
    @listing = listing
    @rule = listing.repricing_rule

    super(
      account: listing.marketplace_account,
      resource: listing
    )
  end

  def run
    return unless @rule

    competitor_price = fetch_competitor_price

    new_price = PriceCalculatorService
                  .new(@listing, competitor_price)
                  .calculate

    return if new_price == @listing.price

    @listing.update!(price: new_price)

    adapter = MarketplaceAdapterResolver.for(@account)

    adapter.update_price(
      @listing,
      new_price
    )

    log_success(
      "repricing",
      "Price updated to #{new_price}"
    )

  rescue => e
    log_failure(
      "repricing",
      e.message
    )
  end

  private

  def fetch_competitor_price
    # placeholder (can integrate later)
    @listing.price
  end
end
