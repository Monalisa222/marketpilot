class CreateSyncEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :sync_events do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :resource_type
      t.integer :resource_id
      t.string :action
      t.string :status
      t.text :message

      t.timestamps
    end

    add_index :sync_events, [ :resource_type, :resource_id ]
  end
end
