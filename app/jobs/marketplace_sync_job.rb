class MarketplaceSyncJob < ApplicationJob
  queue_as :default

  def perform(account_id, sync_type)
    account = MarketplaceAccount.find(account_id)

    case sync_type
    when "orders"
      OrderImportService.new(account).import

    when "products"
      ProductImportService.new(account).import

    when "repricing"
      run_repricing(account)
    end
  end

  private

  def run_repricing(account)
    account.listings.find_each do |listing|
      RepricingJob.perform_later(listing.id)
    end
  end
end
