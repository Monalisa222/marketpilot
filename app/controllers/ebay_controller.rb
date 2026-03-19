require "net/http"

class EbayController < ApplicationController
  skip_before_action :require_login, only: [ :callback ], raise: false

  def connect
    permitted = params.require(:marketplace_account)
                      .permit(:account_name)

    state_data = {
      organization_id: current_organization.id,
      account_name: permitted[:account_name],
      user_id: current_user.id
    }

    encoded_state = Base64.urlsafe_encode64(state_data.to_json)

    redirect_to ebay_auth_url(encoded_state), allow_other_host: true
  end

  def callback
    decoded = JSON.parse(Base64.urlsafe_decode64(params[:state]))

    user = User.find(decoded["user_id"])
    session[:user_id] = user.id
    session[:organization_id] = decoded["organization_id"]

    organization = Organization.find(decoded["organization_id"])
    account_name = decoded["account_name"]

    token = exchange_code(params[:code])

    organization.marketplace_accounts.create!(
      account_name: account_name,
      marketplace: "ebay",
      credentials: {
        access_token: token["access_token"],
        refresh_token: token["refresh_token"],
        expires_at: Time.current + token["expires_in"].to_i.seconds
      }
    )

    redirect_to marketplace_accounts_path, notice: "eBay connected!"
  end

  private

  def ebay_auth_url(state)
    query = URI.encode_www_form(
      client_id: ENV["EBAY_CLIENT_ID"],
      response_type: "code",
      redirect_uri: ENV["EBAY_RUNAME"],
      scope: scopes,
      state: state
    )

    "https://auth.sandbox.ebay.com/oauth2/authorize?#{query}"
  end

  def exchange_code(code)
    uri = URI("https://api.sandbox.ebay.com/identity/v1/oauth2/token")

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/x-www-form-urlencoded"
    request["Authorization"] = "Basic #{Base64.strict_encode64("#{ENV['EBAY_CLIENT_ID']}:#{ENV['EBAY_CLIENT_SECRET']}")}"

    request.body = URI.encode_www_form(
      grant_type: "authorization_code",
      code: code,
      redirect_uri: ENV["EBAY_RUNAME"]
    )

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }

    JSON.parse(response.body) rescue {}
  end

  def scopes
    [
      "https://api.ebay.com/oauth/api_scope",
      "https://api.ebay.com/oauth/api_scope/sell.inventory",
      "https://api.ebay.com/oauth/api_scope/sell.fulfillment"
    ].join(" ")
  end
end
