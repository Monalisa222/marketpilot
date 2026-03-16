class RepricingService
  def initialize(listing)
    @listing = listing
  end

  def run
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
      @listing.variant.sku,
      new_price
    )
  end

  private

  def fetch_competitor_price
    # placeholder — marketplace API will provide this
    @listing.price
  end
end
