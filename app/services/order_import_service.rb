class OrderImportService
  def initialize(account)
    @account = account
    @adapter = MarketplaceAdapterResolver.for(account)
  end

  def import
    orders = @adapter.fetch_orders

    orders.each do |order_data|
      process_order(order_data)
    end
  end

  private

  def process_order(data)
    order = Order.find_or_initialize_by(
      marketplace_account: @account,
      external_id: data[:external_id]
    )

    new_order = order.new_record?

    order.assign_attributes(
      organization: @account.organization,
      status: data[:status],
      total_price: data[:total_price]
    )

    order.save!

    # Preload variants to avoid N+1 queries
    variants = Variant
      .where(sku: data[:items].map { |i| i[:sku] })
      .index_by(&:sku)

    data[:items].each do |item|
      variant = variants[item[:sku]]
      raise "Variant not found for SKU #{item[:sku]}" unless variant

      OrderItem.create!(
        order: order,
        variant: variant,
        quantity: item[:quantity],
        price: item[:price]
      )

      # Only deduct inventory for newly created orders
      if new_order
        InventoryTransactionService
          .new(variant, -item[:quantity])
          .perform
      end
    end

    SyncLoggerService.log(
      organization: @account.organization,
      resource: order,
      action: "order_import",
      status: "success"
    )

  rescue => e

    SyncLoggerService.log(
      organization: @account.organization,
      resource: order,
      action: "order_import",
      status: "failed",
      message: e.message
    )
  end
end
