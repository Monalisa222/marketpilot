class Order < ApplicationRecord
  belongs_to :organization
  belongs_to :marketplace_account

  has_many :order_items, dependent: :destroy
end
