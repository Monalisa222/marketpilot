class OrderImportService < BaseService
  def initialize(account)
    @account = account
    @adapter = MarketplaceAdapterResolver.for(account)

    super(account: account)
  end

  def call
    orders = @adapter.fetch_orders

    log_success("fetch_orders", "Fetched #{orders.size} orders")

    orders.each do |order_data|
      process_order(order_data)
    end

  rescue => e
    log_failure("fetch_orders", e.message)
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

    # set resource context
    @resource = order

    existing_variant_ids = order.order_items.pluck(:variant_id)

    data[:items].each do |item|
      listing = Listing.find_by(
        marketplace_account: @account,
        external_id: item[:external_variant_id]
      )

      unless listing
        log_failure(
          "order_import_missing_listing",
          "Listing not found for #{item[:external_variant_id]}"
        )
        next
      end

      variant = listing.variant

      next if existing_variant_ids.include?(variant.id)

      OrderItem.create!(
        order: order,
        variant: variant,
        quantity: item[:quantity],
        price: item[:price]
      )

      if new_order
        InventoryTransactionService
          .new(variant, -item[:quantity])
          .perform
      end
    end

    log_success("order_import", "Order #{order.external_id} imported")

  rescue => e
    log_failure("order_import", e.message)
  ensure
    @resource = nil
  end
end
