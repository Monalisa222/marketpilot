class ProductsController < ApplicationController
  before_action :require_login

  def index
    @products = ProductCacheService.fetch_products(current_organization)
  end

  def new
    @product = current_organization.products.new
  end

  def create
    @product = current_organization.products.new(product_params)

    if @product.save
      ProductCacheService.clear(current_organization)

      redirect_to products_path, notice: "Product created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @product = current_organization.products.find(params[:id])
  end

  def bulk_push
    account = current_organization.marketplace_accounts.find(
      params[:marketplace_account_id]
    )

    product_ids = current_organization.products
                                    .where(id: params[:product_ids])
                                    .pluck(:id)

    if product_ids.blank?
      redirect_to products_path, alert: "No valid products selected"
      return
    end

    BulkProductPushJob.perform_later(product_ids, account.id)

    redirect_to products_path,
                notice: "#{product_ids.size} products are being pushed"
  end

  private

  def product_params
    params.require(:product).permit(:title, :description)
  end
end
