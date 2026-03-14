class MarketplaceAccount < ApplicationRecord
  belongs_to :organization

  validates :marketplace, presence: true
end
