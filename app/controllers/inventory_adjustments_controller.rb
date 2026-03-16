class InventoryAdjustmentsController < ApplicationController
  before_action :require_login

  def create
    variant = Variant.find(params[:variant_id])

    InventoryTransactionService
      .new(variant, params[:quantity_change].to_i)
      .perform

    redirect_to product_path(variant.product),
      notice: "Inventory updated"
  rescue => e
    redirect_to product_path(variant.product),
      alert: e.message
  end
end
