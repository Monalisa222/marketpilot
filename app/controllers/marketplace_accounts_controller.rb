class MarketplaceAccountsController < ApplicationController
  before_action :require_login

  def index
    @accounts = current_organization.marketplace_accounts
  end

  def new
    @account = MarketplaceAccount.new
  end

  def create
    @account = current_organization.marketplace_accounts.new(account_params)

    if @account.save
      redirect_to marketplace_accounts_path,
        notice: "Marketplace account connected"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def account_params
    params.require(:marketplace_account)
      .permit(:marketplace, :api_key, :api_secret)
  end
end
