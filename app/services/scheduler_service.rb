class SchedulerService
  def self.run_all
    MarketplaceAccount.find_each do |account|
      schedule(account, "products")
      schedule(account, "orders")
      schedule(account, "repricing")
    end
  end

  def self.schedule(account, type)
    MarketplaceSyncJob.perform_later(account.id, type)
  end
end
