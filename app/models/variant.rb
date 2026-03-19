class Variant < ApplicationRecord
  belongs_to :product

  has_many :listings, dependent: :destroy

  validates :sku, presence: true, uniqueness: { scope: :product_id }
end
