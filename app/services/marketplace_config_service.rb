class MarketplaceConfigService
  def self.config
    @config ||= YAML.load_file(
      Rails.root.join("config/marketplaces.yml")
    )
  end

  def self.marketplaces
    config.keys
  end

  def self.credentials_for(marketplace)
    config[marketplace]["credentials"]
  end

  def self.name_for(marketplace)
    config[marketplace]["name"]
  end
end
