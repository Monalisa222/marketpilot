class SyncEventsController < ApplicationController
  before_action :require_login

  def index
    @events = SyncEvent
                .where(organization: current_organization)
                .order(created_at: :desc)
                .limit(100)
  end
end
