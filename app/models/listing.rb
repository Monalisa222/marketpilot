class Listing < ApplicationRecord
  belongs_to :variant
  belongs_to :marketplace_account

  has_one :repricing_rule, dependent: :destroy

  validates :status, presence: true
end
