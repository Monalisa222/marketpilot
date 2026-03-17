class AddAccountNameToMarketplaceAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :marketplace_accounts, :account_name, :string
  end
end
