class DashboardController < ApplicationController
  before_action :require_login

  def index
    @organizations = current_user.organizations
  end
end
