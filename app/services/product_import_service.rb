class ProductImportService
  def initialize(account)
    @account = account
    @adapter = MarketplaceAdapterResolver.for(account)
  end

  def import
    products = @adapter.fetch_products

    products.each do |data|
      create_or_update_product(data)
    end
  end

  private

  def create_or_update_product(data)
    product = Product.find_or_initialize_by(
      organization: @account.organization,
      title: data[:title]
    )

    product.save!

    data[:variants]&.each do |variant_data|
      variant = product.variants.find_or_initialize_by(
        sku: variant_data[:sku] ||  "SKU-#{variant_data[:external_id]}"
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
  end
end
