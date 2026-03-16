class ListingsController < ApplicationController
  before_action :require_login

  def create
    variant = Variant.find(params[:variant_id])

    account = current_organization.marketplace_accounts.find(
      params[:marketplace_account_id]
    )

    variant.listings.create!(
      marketplace_account: account,
      price: variant.price,
      quantity: variant.quantity
    )

    redirect_to product_path(variant.product),
      notice: "Listing created successfully"
  end
end
