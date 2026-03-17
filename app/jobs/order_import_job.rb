class OrderImportJob < ApplicationJob
  queue_as :default

  def perform(account_id)
    account = MarketplaceAccount.find(account_id)

    OrderImportService.new(account).import
  end
end
