class CreateVariants < ActiveRecord::Migration[8.1]
  def change
    create_table :variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :sku, null: false
      t.decimal :price, precision: 10, scale: 2
      t.integer :quantity, default: 0

      t.timestamps
    end

    add_index :variants, :sku, unique: true
  end
end
