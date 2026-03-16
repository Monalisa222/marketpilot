class OrganizationSwitchesController < ApplicationController
  before_action :require_login

  def create
    organization = current_user.organizations.find(params[:organization_id])

    session[:organization_id] = organization.id

    redirect_to dashboard_path, notice: "Switched organization"
  end
end
