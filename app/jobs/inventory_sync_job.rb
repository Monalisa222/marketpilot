class InventorySyncJob < ApplicationJob
  queue_as :default

  def perform(variant_id)
    variant = Variant.find(variant_id)

    InventorySyncService.new(variant).sync
  end
end
