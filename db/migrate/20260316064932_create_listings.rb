class CreateListings < ActiveRecord::Migration[8.1]
  def change
    create_table :listings do |t|
      t.references :variant, null: false, foreign_key: true
      t.references :marketplace_account, null: false, foreign_key: true
      t.string :external_id
      t.decimal :price, precision: 10, scale: 2
      t.integer :quantity
      t.string :status, default: "active"

      t.timestamps
    end

    add_index :listings, [ :variant_id, :marketplace_account_id ], unique: true
  end
end
