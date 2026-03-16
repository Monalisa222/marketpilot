class MarketplaceApiClient
  MAX_RETRIES = 3

  def initialize(account)
    @account = account
  end

  def perform_request(action)
    key = "api:#{@account.marketplace}:#{@account.id}"

    raise "Rate limit exceeded" unless ApiRateLimiter.allow?(key)

    retries = 0

    begin
      action.call

    rescue => e

      SyncEventloggerService.log(
        organization: @account.organization,
        resource: @account,
        action: "api_request",
        status: "failure",
        message: e.message
      )

      retries += 1

      if retries <= MAX_RETRIES
        sleep(2 ** retries)
        retry
      else
        raise e
      end

    end
  end
end
