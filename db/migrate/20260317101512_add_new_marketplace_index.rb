class AddNewMarketplaceIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :marketplace_accounts, [ :organization_id, :account_name ], unique: true
  end
end
