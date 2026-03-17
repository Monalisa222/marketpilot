class RemoveOldCredentialsFromMarketplaceAccounts < ActiveRecord::Migration[8.1]
  def change
    remove_column :marketplace_accounts, :api_key, :string
    remove_column :marketplace_accounts, :api_secret, :string
  end
end
