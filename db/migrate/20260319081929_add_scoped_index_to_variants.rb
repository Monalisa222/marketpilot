class AddScopedIndexToVariants < ActiveRecord::Migration[8.1]
  def change
    add_index :variants, [ :product_id, :sku ], unique: true
  end
end
