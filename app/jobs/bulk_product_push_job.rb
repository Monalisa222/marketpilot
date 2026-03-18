class BulkProductPushJob < ApplicationJob
  queue_as :default

  def perform(product_ids, account_id)
    account = MarketplaceAccount.find_by(id: account_id)
    return unless account

    products = Product.where(id: product_ids)

    BulkProductPushService.new(products, account).push
  rescue => e
    SyncLoggerService.log(
      organization: account&.organization,
      resource: nil,
      action: "bulk_product_push_job",
      status: "failed",
      message: e.message
    )

    raise e
  end
end
