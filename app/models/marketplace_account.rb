class MarketplaceAccount < ApplicationRecord
  belongs_to :organization

  has_many :listings, dependent: :destroy

  validates :account_name, uniqueness: { scope: :organization_id }
  validates :marketplace, presence: true

  validate :validate_credentials_presence

  def credential(key)
    credentials[key.to_s]
  end

  private

  def validate_credentials_presence
    required_fields = MarketplaceConfigService.config
                        .dig(marketplace, "credentials") || []

    required_fields.each do |field|
      if (credentials || {})[field].blank?
        errors.add(:base, "#{field.humanize} can't be blank")
      end
    end
  end
end
