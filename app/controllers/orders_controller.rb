class OrdersController < ApplicationController
  before_action :require_login

  def index
    @orders = Order
                .where(organization: current_organization)
                .order(created_at: :desc)
  end

  def show
    @order = Order.find(params[:id])
  end
end
