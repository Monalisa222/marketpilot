class Variant < ApplicationRecord
  belongs_to :product

  validates :sku, presence: true, uniqueness: true
end
