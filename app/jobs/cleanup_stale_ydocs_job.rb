class CleanupStaleYdocsJob < ApplicationJob
  queue_as :default

  def perform
    # Full implementation in US-046
  end
end
