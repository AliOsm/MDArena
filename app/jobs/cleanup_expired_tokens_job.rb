class CleanupExpiredTokensJob < ApplicationJob
  queue_as :default

  def perform
    # Full implementation in US-045
  end
end
