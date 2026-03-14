class OrganizationsController < ApplicationController
  before_action :require_login

  def new
    @organization = Organization.new
  end

  def create
    @organization = Organization.new(organization_params)

    if @organization.save
      Membership.create!(
        user: current_user,
        organization: @organization,
        role: "owner"
      )

      redirect_to dashboard_path, notice: "Organization created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def organization_params
    params.require(:organization).permit(:name)
  end
end
