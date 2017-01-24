class CleanupJob < ActiveJob::Base
  queue_as :default

  def perform(*args)
    CleanupJob.set(wait_until: 5.minutes.since).perform_later('Foo')
  end
end
