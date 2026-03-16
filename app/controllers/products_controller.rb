class ProductsController < ApplicationController
  before_action :require_login

  def index
    @products = current_organization.products
  end

  def new
    @product = current_organization.products.new
  end

  def create
    @product = current_organization.products.new(product_params)

    if @product.save
      redirect_to products_path, notice: "Product created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @product = current_organization.products.find(params[:id])
  end

  private

  def product_params
    params.require(:product).permit(:title, :description)
  end
end
