class SyncLoggerService
  def self.log(organization:, resource:, action:, status:, message: nil)
    SyncEvent.create!(
      organization: organization,
      resource_type: resource&.class&.name,
      resource_id: resource&.id,
      action: action,
      status: status,
      message: message
    )
  end
end
