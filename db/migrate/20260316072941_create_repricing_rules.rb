class CreateRepricingRules < ActiveRecord::Migration[8.1]
  def change
    create_table :repricing_rules do |t|
      t.references :listing, null: false, foreign_key: true
      t.decimal :min_price, precision: 10, scale: 2
      t.decimal :max_price, precision: 10, scale: 2
      t.decimal :adjustment, precision: 10, scale: 2
      t.string :strategy, default: "undercut"

      t.timestamps
    end
  end
end
