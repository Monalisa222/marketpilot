class SyncController < ApplicationController
  def index
    @accounts = MarketplaceAccount.all
  end

  def sync_orders
    account = MarketplaceAccount.find(params[:account_id])
    MarketplaceSyncJob.perform_later(account.id, "orders")

    redirect_to sync_index_path, notice: "Order sync started"
  end

  def sync_products
    account = MarketplaceAccount.find(params[:account_id])
    MarketplaceSyncJob.perform_later(account.id, "products")

    redirect_to sync_index_path, notice: "Product sync started"
  end

  def sync_repricing
    account = MarketplaceAccount.find(params[:account_id])
    MarketplaceSyncJob.perform_later(account.id, "repricing")

    redirect_to sync_index_path, notice: "Repricing started"
  end
end
