namespace :scheduler do
  desc "Run marketplace sync jobs"

  task run: :environment do
    SchedulerService.run_all
  end
end
