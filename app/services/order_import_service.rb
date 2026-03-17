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

    # ✅ Prevent duplicate items
    existing_variant_ids = order.order_items.pluck(:variant_id)

    data[:items].each do |item|
      # 1. Find listing (marketplace mapping)
      listing = Listing.find_by(
        marketplace_account: @account,
        external_id: item[:external_variant_id]
      )

      unless listing
        SyncLoggerService.log(
          organization: @account.organization,
          resource: order,
          action: "order_import_missing_listing",
          status: "failed",
          message: "Listing not found for #{item[:external_variant_id]}"
        )
        next
      end

      variant = listing.variant

      # 2. Idempotency check
      next if existing_variant_ids.include?(variant.id)

      # 3. Create order item
      OrderItem.create!(
        order: order,
        variant: variant,
        quantity: item[:quantity],
        price: item[:price]
      )

      # 4. Inventory deduction (only once)
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
