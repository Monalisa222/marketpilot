class AddCredentialsToMarketplaceAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :marketplace_accounts, :credentials, :jsonb, default: {}
  end
end
