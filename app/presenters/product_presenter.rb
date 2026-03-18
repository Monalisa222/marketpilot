class ProductPresenter
  attr_reader :product, :listings_count

  def initialize(product, listings_count)
    @product = product
    @listings_count = listings_count
  end

  # Delegate common methods
  def id
    product.id
  end

  def title
    product.title
  end

  def status
    product.status
  end

  def listings_count
    @listings_count || 0
  end

  # Optional helper
  def listings_path
    Rails.application.routes.url_helpers.listings_path(product_id: product.id)
  end
end
