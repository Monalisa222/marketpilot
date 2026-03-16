class RepricingRule < ApplicationRecord
  belongs_to :listing

  validates :strategy, presence: true
end
