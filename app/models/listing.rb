class Listing < ApplicationRecord
  belongs_to :variant
  belongs_to :marketplace_account

  validates :status, presence: true
end
