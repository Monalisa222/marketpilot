class RepricingRulesController < ApplicationController
  before_action :require_login

  def create
    listing = Listing.find(params[:listing_id])

    listing.create_repricing_rule!(rule_params)

    redirect_to product_path(listing.variant.product),
      notice: "Repricing rule created"
  end

  def update
    rule = RepricingRule.find(params[:id])

    if rule.update(rule_params)
      redirect_to product_path(rule.listing.variant.product),
        notice: "Repricing rule updated"
    else
      redirect_to product_path(rule.listing.variant.product),
        alert: rule.errors.full_messages.join(", ")
    end
  end

  private

  def rule_params
    params.require(:repricing_rule)
      .permit(:min_price, :max_price, :adjustment, :strategy)
  end
end
