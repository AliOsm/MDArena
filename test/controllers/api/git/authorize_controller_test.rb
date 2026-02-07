require "test_helper"

class Api::Git::AuthorizeControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear

    @alice = users(:alice)
    @bob = users(:bob)
    @alpha = projects(:alpha)

    @password = "password123"
  end

  test "returns 200 for valid credentials and project membership" do
    get api_git_authorize_path, headers: auth_headers(@alice.email, @password, read_uri(@alpha.slug))

    assert_response :ok
  end

  test "returns X-Repo-UUID header on successful auth" do
    get api_git_authorize_path, headers: auth_headers(@alice.email, @password, read_uri(@alpha.slug))

    assert_equal @alpha.uuid, response.headers["X-Repo-UUID"]
  end

  test "returns 401 when no authorization header" do
    get api_git_authorize_path, headers: { "X-Original-URI" => "/git/#{@alpha.slug}.git/info/refs" }

    assert_response :unauthorized
  end

  test "returns 401 for invalid password" do
    get api_git_authorize_path, headers: auth_headers(@alice.email, "wrong-password", read_uri(@alpha.slug))

    assert_response :unauthorized
  end

  test "returns 401 for wrong user email" do
    get api_git_authorize_path, headers: auth_headers("nobody@example.com", @password, read_uri(@alpha.slug))

    assert_response :unauthorized
  end

  test "returns 401 when password is for different user" do
    get api_git_authorize_path, headers: auth_headers(@bob.email, "wrong-password", read_uri(@alpha.slug))

    assert_response :unauthorized
  end

  test "returns 403 for non-member" do
    admin = users(:admin)

    get api_git_authorize_path, headers: auth_headers(admin.email, @password, read_uri(@alpha.slug))

    assert_response :forbidden
  end

  test "allows push for editor" do
    get api_git_authorize_path, headers: auth_headers(@bob.email, @password, push_uri(@alpha.slug))

    assert_response :ok
  end

  test "allows push for owner" do
    get api_git_authorize_path, headers: auth_headers(@alice.email, @password, push_uri(@alpha.slug))

    assert_response :ok
  end

  test "returns 400 when X-Original-URI is missing" do
    credentials = Base64.strict_encode64("#{@alice.email}:#{@password}")
    get api_git_authorize_path, headers: { "Authorization" => "Basic #{credentials}" }

    assert_response :bad_request
  end

  test "returns 429 when rate limit exceeded" do
    headers = auth_headers(@alice.email, @password, read_uri(@alpha.slug))

    60.times do
      get api_git_authorize_path, headers: headers

      assert_response :ok
    end

    get api_git_authorize_path, headers: headers

    assert_response :too_many_requests
  end

  private

  def auth_headers(email, password, original_uri)
    credentials = Base64.strict_encode64("#{email}:#{password}")
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
