class OrderImportJob < ApplicationJob
  queue_as :critical

  def perform(account_id)
    account = MarketplaceAccount.find(account_id)

    OrderImportService.new(account).call
  end
end
