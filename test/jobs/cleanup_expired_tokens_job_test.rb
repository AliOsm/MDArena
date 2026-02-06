require "test_helper"

class CleanupExpiredTokensJobTest < ActiveJob::TestCase
  test "deletes expired tokens" do
    expired = personal_access_tokens(:expired_token)
    assert_difference("PersonalAccessToken.count", -1) do
      CleanupExpiredTokensJob.perform_now
    end
    assert_not PersonalAccessToken.exists?(expired.id)
  end

  test "deletes tokens revoked more than 30 days ago" do
    old_revoked = PersonalAccessToken.create!(
      user: users(:alice),
      name: "Old Revoked",
      token_digest: Digest::SHA256.hexdigest("old_revoked_token"),
      token_prefix: "old_revo",
      revoked_at: 31.days.ago
    )

    CleanupExpiredTokensJob.perform_now

    assert_not PersonalAccessToken.exists?(old_revoked.id)
  end

  test "keeps active tokens" do
    active = personal_access_tokens(:active_token)
    CleanupExpiredTokensJob.perform_now

    assert PersonalAccessToken.exists?(active.id)
  end

  test "keeps recently revoked tokens" do
    recent_revoked = personal_access_tokens(:revoked_token)
    CleanupExpiredTokensJob.perform_now

    assert PersonalAccessToken.exists?(recent_revoked.id)
  end
end
