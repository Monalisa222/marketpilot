class MarketplaceAccount < ApplicationRecord
  belongs_to :organization

  has_many :listings, dependent: :destroy

  validates :marketplace, presence: true
end
