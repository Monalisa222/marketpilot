class ProductPushService
  def initialize(product, account)
    @product = product
    @account = account
  end

  def push
    strategy.call
  end

  private

  def strategy
    "Integrations::#{@account.marketplace.camelize}::ProductCreator"
      .constantize
      .new(@product, @account)
  rescue NameError
    raise "Marketplace not supported: #{@account.marketplace}"
  end
end
