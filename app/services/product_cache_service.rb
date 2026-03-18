class ProductCacheService
  CACHE_TTL = 5.minutes

  def self.fetch_products(organization)
    products = Rails.cache.fetch(cache_key(organization), expires_in: CACHE_TTL) do
      organization.products.includes(:variants).to_a
    end

    listing_counts = Listing
      .joins(:variant)
      .where(variants: { product_id: products.map(&:id) })
      .group("variants.product_id")
      .count

    # Wrap products in presenter
    products.map do |product|
      ::ProductPresenter.new(product, listing_counts[product.id])
    end
  end

  def self.clear(organization)
    Rails.cache.delete(cache_key(organization))
  end

  def self.cache_key(org)
    "org:#{org.id}:products"
  end
end
