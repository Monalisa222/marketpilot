class Organization < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  has_many :marketplace_accounts, dependent: :destroy
  has_many :products, dependent: :destroy

  validates :name, presence: true
end
