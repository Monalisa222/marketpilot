class InventoryTransactionService
  MAX_RETRIES = 3

  def initialize(variant, quantity_change)
    @variant = variant
    @quantity_change = quantity_change
  end

  def perform
    retries ||= 0

    Variant.transaction do
      @variant.lock!

      new_quantity = @variant.quantity + @quantity_change
      raise "Inventory cannot be negative" if new_quantity < 0

      @variant.update!(quantity: new_quantity)

      InventorySyncJob.perform_later(@variant.id)
    end

  rescue ActiveRecord::Deadlocked
    retries += 1
    retry if retries < MAX_RETRIES
    raise
  end
end
