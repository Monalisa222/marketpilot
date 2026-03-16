class VariantsController < ApplicationController
  before_action :require_login

  def create
    product = current_organization.products.find(params[:product_id])

    @variant = product.variants.new(variant_params)

    if @variant.save
      redirect_to product_path(product), notice: "Variant created successfully"
    else
      redirect_to product_path(product), alert: @variant.errors.full_messages.join(", ")
    end
  end

  def update
    @variant = Variant.find(params[:id])

    if @variant.update(variant_params)
      InventorySyncService.new(@variant).sync
      PriceSyncService.new(@variant).sync

      redirect_to product_path(@variant.product), notice: "Variant updated"
    else
      redirect_to product_path(@variant.product), alert: @variant.errors.full_messages.join(", ")
    end
  end

  private

  def variant_params
    params.require(:variant).permit(:sku, :price, :quantity)
  end
end
