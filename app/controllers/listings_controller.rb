class ListingsController < ApplicationController
  before_action :require_login

  def create
    variant = current_organization
                .products
                .joins(:variants)
                .merge(Variant.where(id: params[:variant_id]))
                .first
                &.variants
                &.find(params[:variant_id])

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

  def update
    listing = Listing.find(params[:id])

    if listing.update(listing_params)
      redirect_to product_path(listing.variant.product),
        notice: "Listing updated"
    else
      redirect_to product_path(listing.variant.product),
        alert: listing.errors.full_messages.join(", ")
    end
  end

  def destroy
    listing = Listing.find(params[:id])
    product = listing.variant.product

    listing.destroy

    redirect_to product_path(product),
      notice: "Listing removed"
  end

  private

  def listing_params
    params.require(:listing).permit(:price, :quantity, :status)
  end
end
