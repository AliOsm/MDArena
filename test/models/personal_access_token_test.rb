require "test_helper"

class PersonalAccessTokenTest < ActiveSupport::TestCase
  test "token creation stores digest and prefix" do
    user = users(:alice)
    pat = user.personal_access_tokens.create!(name: "Test Token")

    assert_predicate pat.token, :present?, "plain token should be accessible after creation"
    assert_equal Digest::SHA256.hexdigest(pat.token), pat.token_digest
    assert_equal pat.token[0, 8], pat.token_prefix
  end

  test "plain token is not persisted in DB" do
    user = users(:alice)
    pat = user.personal_access_tokens.create!(name: "Test Token")
    reloaded = PersonalAccessToken.find(pat.id)

    assert_nil reloaded.token
  end

  test "authenticate returns PAT for valid active token" do
    user = users(:alice)
    pat = user.personal_access_tokens.create!(name: "Auth Test", expires_at: 7.days.from_now)
    plain_token = pat.token

    found = PersonalAccessToken.authenticate(plain_token)

    assert_equal pat.id, found.id
  end

  test "authenticate returns nil for revoked token" do
    user = users(:alice)
    pat = user.personal_access_tokens.create!(name: "Revoked Test")
    plain_token = pat.token
    pat.revoke!

    assert_nil PersonalAccessToken.authenticate(plain_token)
  end

  test "authenticate returns nil for expired token" do
    user = users(:alice)
    pat = user.personal_access_tokens.create!(name: "Expired Test", expires_at: 1.hour.ago)
    plain_token = pat.token

    assert_nil PersonalAccessToken.authenticate(plain_token)
  end

  test "authenticate returns nil for unknown token" do
    assert_nil PersonalAccessToken.authenticate("nonexistent_token_value")
  end

  test "revoke sets revoked_at" do
    user = users(:alice)
    pat = user.personal_access_tokens.create!(name: "Revoke Test")

    assert_nil pat.revoked_at
    pat.revoke!

    assert_not_nil pat.reload.revoked_at
  end

  test "active scope excludes revoked and expired tokens" do
    user = users(:alice)
    active = user.personal_access_tokens.create!(name: "Active", expires_at: 7.days.from_now)
    revoked = user.personal_access_tokens.create!(name: "Revoked")
    revoked.revoke!
    user.personal_access_tokens.create!(name: "Expired", expires_at: 1.hour.ago)

    active_tokens = user.personal_access_tokens.active

    assert_includes active_tokens, active
    assert_equal 1, active_tokens.where(name: %w[Active Revoked Expired]).count
  end
end
