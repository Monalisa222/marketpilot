class PriceSyncJob < ApplicationJob
  queue_as :default

  def perform(variant_id)
    variant = Variant.find(variant_id)

    PriceSyncService.new(variant).sync
  end
end
