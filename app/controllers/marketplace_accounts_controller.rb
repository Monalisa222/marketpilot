class MarketplaceAccountsController < ApplicationController
  before_action :require_login

  def index
    @accounts = current_organization.marketplace_accounts
  end

  def new
    @account = MarketplaceAccount.new
  end

  def create
    @account = current_organization.marketplace_accounts.new(marketplace_account_params)

    if @account.save
      redirect_to marketplace_accounts_path,
        notice: "Marketplace account connected"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def marketplace_account_params
    params.require(:marketplace_account)
          .permit(:marketplace, :account_name)
          .merge(credentials: credentials_params)
  end

  def credentials_params
    marketplace = params.dig(:marketplace_account, :marketplace)

    allowed_fields = MarketplaceConfigService.config
                      .dig(marketplace, "credentials") || []

    return {} unless params[:credentials].present?

    params.require(:credentials).permit(*allowed_fields).to_h
  end
end
