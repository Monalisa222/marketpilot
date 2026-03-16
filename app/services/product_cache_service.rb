class ProductCacheService
  CACHE_TTL = 5.minutes

  def self.fetch_products(organization)
    Rails.cache.fetch(cache_key(organization), expires_in: CACHE_TTL) do
      organization.products.includes(:variants).to_a
    end
  end

  def self.clear(organization)
    Rails.cache.delete(cache_key(organization))
  end

  def self.cache_key(org)
    "org:#{org.id}:products"
  end
end
