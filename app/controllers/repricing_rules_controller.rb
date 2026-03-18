class RepricingRulesController < ApplicationController
  before_action :require_login

  def new
    @listing = Listing.find(params[:listing_id])
    @rule = @listing.build_repricing_rule
  end

  def create
    listing = Listing.find(params[:listing_id])
    listing.create_repricing_rule!(rule_params)

    redirect_to listings_path(product_id: listing.variant.product_id),
      notice: "Repricing rule created"
  end

  def edit
    @rule = RepricingRule.find(params[:id])
  end

  def update
    @rule = RepricingRule.find(params[:id])

    if @rule.update(rule_params)
      redirect_to listings_path(product_id: @rule.listing.variant.product_id),
        notice: "Repricing rule updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def rule_params
    params.require(:repricing_rule)
      .permit(:min_price, :max_price, :adjustment, :strategy)
  end
end
