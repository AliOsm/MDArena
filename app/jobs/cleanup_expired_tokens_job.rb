class CleanupExpiredTokensJob < ApplicationJob
  queue_as :default

  def perform
    PersonalAccessToken.where("expires_at < ?", Time.current)
      .or(PersonalAccessToken.where("revoked_at < ?", 30.days.ago))
      .delete_all
  end
end
