class DashboardController < ApplicationController
  before_action :require_login
  before_action :set_default_organization

  def index
    @organizations = current_user.organizations
  end

  private

  def set_default_organization
    if session[:organization_id].nil? && current_user.organizations.any?
      session[:organization_id] = current_user.organizations.first.id
    end
  end
end
