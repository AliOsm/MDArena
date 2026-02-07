require "test_helper"

class Api::Git::AuthorizeControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear

    @alice = users(:alice)
    @bob = users(:bob)
    @alpha = projects(:alpha)

    @token_value = SecureRandom.base58(24)
    @pat = PersonalAccessToken.create!(user: @alice, name: "Git Token")
    @plain_token = @pat.token
  end

  test "returns 200 for valid credentials and project membership" do
    get api_git_authorize_path, headers: auth_headers(@alice.email, @plain_token, read_uri(@alpha.slug))

    assert_response :ok
  end

  test "returns X-Repo-UUID header on successful auth" do
    get api_git_authorize_path, headers: auth_headers(@alice.email, @plain_token, read_uri(@alpha.slug))

    assert_equal @alpha.uuid, response.headers["X-Repo-UUID"]
  end

  test "returns 401 when no authorization header" do
    get api_git_authorize_path, headers: { "X-Original-URI" => "/git/#{@alpha.slug}.git/info/refs" }

    assert_response :unauthorized
  end

  test "returns 401 for invalid token" do
    get api_git_authorize_path, headers: auth_headers(@alice.email, "invalid-token", read_uri(@alpha.slug))

    assert_response :unauthorized
  end

  test "returns 401 for wrong user email" do
    get api_git_authorize_path, headers: auth_headers("nobody@example.com", @plain_token, read_uri(@alpha.slug))

    assert_response :unauthorized
  end

  test "returns 401 when token belongs to different user" do
    get api_git_authorize_path, headers: auth_headers(@bob.email, @plain_token, read_uri(@alpha.slug))

    assert_response :unauthorized
  end

  test "returns 403 for non-member" do
    admin = users(:admin)
    admin_pat = PersonalAccessToken.create!(user: admin, name: "Admin Token")

    get api_git_authorize_path, headers: auth_headers(admin.email, admin_pat.token, read_uri(@alpha.slug))

    assert_response :forbidden
  end

  test "allows push for editor" do
    bob_pat = PersonalAccessToken.create!(user: @bob, name: "Bob Token")

    get api_git_authorize_path, headers: auth_headers(@bob.email, bob_pat.token, push_uri(@alpha.slug))

    assert_response :ok
  end

  test "allows push for owner" do
    get api_git_authorize_path, headers: auth_headers(@alice.email, @plain_token, push_uri(@alpha.slug))

    assert_response :ok
  end

  test "touches last_used_at on successful auth" do
    assert_nil @pat.reload.last_used_at
    get api_git_authorize_path, headers: auth_headers(@alice.email, @plain_token, read_uri(@alpha.slug))

    assert_response :ok
    assert_not_nil @pat.reload.last_used_at
  end

  test "returns 400 when X-Original-URI is missing" do
    credentials = Base64.strict_encode64("#{@alice.email}:#{@plain_token}")
    get api_git_authorize_path, headers: { "Authorization" => "Basic #{credentials}" }

    assert_response :bad_request
  end

  test "returns 429 when rate limit exceeded" do
    headers = auth_headers(@alice.email, @plain_token, read_uri(@alpha.slug))

    60.times do
      get api_git_authorize_path, headers: headers

      assert_response :ok
    end

    get api_git_authorize_path, headers: headers

    assert_response :too_many_requests
  end

  private

  def auth_headers(email, token, original_uri)
    credentials = Base64.strict_encode64("#{email}:#{token}")
    {
      "Authorization" => "Basic #{credentials}",
      "X-Original-URI" => original_uri
    }
  end

  def read_uri(slug)
    "/git/#{slug}.git/info/refs?service=git-upload-pack"
  end

  def push_uri(slug)
    "/git/#{slug}.git/git-receive-pack"
  end
end
