class RemoveOldMarketplaceIndex < ActiveRecord::Migration[8.1]
  def change
    remove_index :marketplace_accounts, [ :organization_id, :marketplace ]
  end
end
