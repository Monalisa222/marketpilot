class Product < ApplicationRecord
  belongs_to :organization

  has_many :variants, dependent: :destroy

  validates :title, presence: true
end
