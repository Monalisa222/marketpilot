class SyncEvent < ApplicationRecord
  belongs_to :organization

  validates :action, presence: true
  validates :status, presence: true
end
