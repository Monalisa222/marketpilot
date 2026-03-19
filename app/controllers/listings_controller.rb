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

      price_result = adapter.update_price(@listing, @listing.price)
      inventory_result = adapter.update_inventory(@listing, @listing.quantity)

      [ price_result, inventory_result ].each do |result|
        next if result.nil?

        if result[:success]
          SyncLoggerService.log(
            organization: @listing.marketplace_account.organization,
            resource: @listing,
            action: "listing_sync",
            status: "success",
            message: result[:message]
          )
        else
          SyncLoggerService.log(
            organization: @listing.marketplace_account.organization,
            resource: @listing,
            action: "listing_sync",
            status: "failed",
            message: result[:error]
          )
        end
      end

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
