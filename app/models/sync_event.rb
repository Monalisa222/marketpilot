class SyncEvent < ApplicationRecord
  belongs_to :organization

  validates :resource_type, presence: true
  validates :resource_id, presence: true
  validates :action, presence: true
  validates :status, presence: true
end
