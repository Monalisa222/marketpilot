class ProductImportService < BaseService
  def initialize(account)
    @account = account
    @adapter = MarketplaceAdapterResolver.for(account)

    super(account: account)
  end

  def call
    products = @adapter.fetch_products

    log_success("fetch_products", "Fetched #{products.size} products")

    products.each do |data|
      create_or_update_product(data)
    end

  rescue => e
    log_failure("fetch_products", e.message)
  end

  private

  def create_or_update_product(data)
    product = Product.find_or_initialize_by(
      organization: @account.organization,
      title: data[:title]
    )

    product.save!

    # set resource context
    @resource = product

    data[:variants]&.each do |variant_data|
      variant = product.variants.find_or_initialize_by(
        sku: variant_data[:sku] || "SKU-#{variant_data[:external_id]}"
      )

      variant.update!(
        price: variant_data[:price],
        quantity: variant_data[:quantity]
      )

      listing = Listing.find_or_initialize_by(
        marketplace_account: @account,
        external_id: variant_data[:external_id]
      )

      listing.update!(
        variant: variant,
        price: variant_data[:price],
        quantity: variant_data[:quantity]
      )
    end

    log_success("product_import", "Product #{product.title} synced")

  rescue => e
    log_failure("product_import", e.message)
  end
end
