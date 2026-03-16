class RepricingJob < ApplicationJob
  queue_as :default

  def perform(listing_id)
    listing = Listing.find(listing_id)

    RepricingService.new(listing).run
  end
end
