class ListingsController < ApplicationController
  before_action :require_login

  def index
    @listings = Listing
                  .joins(:variant)
                  .where(variants: { product_id: params[:product_id] })
  end

  def edit
    @listing = Listing.find(params[:id])
  end

  def update
    @listing = Listing.find(params[:id])

    if @listing.update(listing_params)

      # trigger sync
      adapter = MarketplaceAdapterResolver.for(@listing.marketplace_account)

      adapter.update_price(@listing.external_id, @listing.price)
      adapter.update_inventory(@listing.external_id, @listing.quantity)

      redirect_to listings_path(product_id: @listing.variant.product_id),
        notice: "Listing updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def listing_params
    params.require(:listing).permit(:price, :quantity, :status)
  end
end
