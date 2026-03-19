# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_19_081929) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "listings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id"
    t.bigint "marketplace_account_id", null: false
    t.decimal "price", precision: 10, scale: 2
    t.integer "quantity"
    t.string "status", default: "active"
    t.datetime "updated_at", null: false
    t.bigint "variant_id", null: false
    t.index ["marketplace_account_id"], name: "index_listings_on_marketplace_account_id"
    t.index ["variant_id", "marketplace_account_id"], name: "index_listings_on_variant_id_and_marketplace_account_id", unique: true
    t.index ["variant_id"], name: "index_listings_on_variant_id"
  end

  create_table "marketplace_accounts", force: :cascade do |t|
    t.string "account_name"
    t.datetime "created_at", null: false
    t.jsonb "credentials", default: {}
    t.string "marketplace", null: false
    t.bigint "organization_id", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "account_name"], name: "index_marketplace_accounts_on_organization_id_and_account_name", unique: true
    t.index ["organization_id"], name: "index_marketplace_accounts_on_organization_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "organization_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["user_id", "organization_id"], name: "index_memberships_on_user_id_and_organization_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "order_id", null: false
    t.decimal "price", precision: 10, scale: 2
    t.integer "quantity"
    t.datetime "updated_at", null: false
    t.bigint "variant_id", null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["variant_id"], name: "index_order_items_on_variant_id"
  end

  create_table "orders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id"
    t.bigint "marketplace_account_id", null: false
    t.bigint "organization_id", null: false
    t.string "status"
    t.decimal "total_price", precision: 10, scale: 2
    t.datetime "updated_at", null: false
    t.index ["marketplace_account_id", "external_id"], name: "index_orders_on_marketplace_account_id_and_external_id", unique: true
    t.index ["marketplace_account_id"], name: "index_orders_on_marketplace_account_id"
    t.index ["organization_id"], name: "index_orders_on_organization_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "organization_id", null: false
    t.string "status", default: "active"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_products_on_organization_id"
  end

  create_table "repricing_rules", force: :cascade do |t|
    t.decimal "adjustment", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.bigint "listing_id", null: false
    t.decimal "max_price", precision: 10, scale: 2
    t.decimal "min_price", precision: 10, scale: 2
    t.string "strategy", default: "undercut"
    t.datetime "updated_at", null: false
    t.index ["listing_id"], name: "index_repricing_rules_on_listing_id"
  end

  create_table "sync_events", force: :cascade do |t|
    t.string "action"
    t.datetime "created_at", null: false
    t.text "message"
    t.bigint "organization_id", null: false
    t.integer "resource_id"
    t.string "resource_type"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_sync_events_on_organization_id"
    t.index ["resource_type", "resource_id"], name: "index_sync_events_on_resource_type_and_resource_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "variants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "price", precision: 10, scale: 2
    t.bigint "product_id", null: false
    t.integer "quantity", default: 0
    t.string "sku", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "sku"], name: "index_variants_on_product_id_and_sku", unique: true
    t.index ["product_id"], name: "index_variants_on_product_id"
  end

  add_foreign_key "listings", "marketplace_accounts"
  add_foreign_key "listings", "variants"
  add_foreign_key "marketplace_accounts", "organizations"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "variants"
  add_foreign_key "orders", "marketplace_accounts"
  add_foreign_key "orders", "organizations"
  add_foreign_key "products", "organizations"
  add_foreign_key "repricing_rules", "listings"
  add_foreign_key "sync_events", "organizations"
  add_foreign_key "variants", "products"
end
