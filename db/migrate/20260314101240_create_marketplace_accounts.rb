class CreateMarketplaceAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :marketplace_accounts do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :marketplace, null: false
      t.string :api_key
      t.string :api_secret
      t.string :status, default: "active", null: false

      t.timestamps
    end

    add_index :marketplace_accounts, [ :organization_id, :marketplace ], unique: true
  end
end
