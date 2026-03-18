class BulkProductPushService < BaseService
  def initialize(products, account)
    super(account: account)

    @products = products
  end

  def push
    @products.find_each do |product|
      set_resource(product)

      ProductPushService.new(product, @account).push

      log_success("bulk_product_push", "Product #{product.id} pushed")
    rescue => e
      log_failure("bulk_product_push", "Product #{product.id} failed: #{e.message}")
    end
  end

  private

  def set_resource(resource)
    @resource = resource
  end
end
