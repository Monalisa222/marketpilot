class PriceCalculatorService
  def initialize(listing, competitor_price)
    @listing = listing
    @rule = listing.repricing_rule
    @competitor_price = competitor_price
  end

  def calculate
    return @listing.price unless @rule

    price =
      case @rule.strategy
      when "undercut"
        @competitor_price - @rule.adjustment
      when "match"
        @competitor_price
      else
        @listing.price
      end

    apply_bounds(price)
  end

  private

  def apply_bounds(price)
    price = @rule.min_price if @rule.min_price && price < @rule.min_price
    price = @rule.max_price if @rule.max_price && price > @rule.max_price
    price
  end
end
