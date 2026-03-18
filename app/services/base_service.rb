class BaseService
  def initialize(account:, resource: nil)
    @account = account
    @resource = resource
  end

  private

  def log_success(action, message)
    log("success", action, message)
  end

  def log_failure(action, message)
    log("failed", action, message)
  end

  def log(status, action, message)
    SyncLoggerService.log(
      organization: @account.organization,
      resource: @resource,
      action: action,
      status: status,
      message: message
    )
  end
end
