class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :marketplace_account, null: false, foreign_key: true
      t.string :external_id
      t.string :status
      t.decimal :total_price, precision: 10, scale: 2

      t.timestamps
    end

    add_index :orders, [ :marketplace_account_id, :external_id ], unique: true
  end
end
