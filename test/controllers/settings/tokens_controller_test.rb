require "test_helper"

class Settings::TokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:alice)
    sign_in @user
  end

  test "index renders tokens page with user tokens" do
    get settings_tokens_path

    assert_response :success
  end

  test "index only shows current user tokens" do
    bob = users(:bob)
    bob_token_count = bob.personal_access_tokens.count
    alice_token_count = @user.personal_access_tokens.count

    assert_operator alice_token_count, :>, 0
    assert_operator bob_token_count, :>, 0

    get settings_tokens_path

    assert_response :success
  end

  test "create generates a new token and redirects with flash" do
    assert_difference("PersonalAccessToken.count", 1) do
      post settings_tokens_path, params: { name: "Deploy Key" }
    end

    assert_redirected_to settings_tokens_path
    assert_not_nil flash[:new_token]
  end

  test "destroy revokes token and redirects" do
    token = personal_access_tokens(:active_token)

    assert_nil token.revoked_at

    delete settings_token_path(token)

    assert_redirected_to settings_tokens_path
    assert_not_nil token.reload.revoked_at
  end

  test "destroy cannot revoke another user token" do
    bob_token = personal_access_tokens(:expired_token) # belongs to bob

    delete settings_token_path(bob_token)

    assert_response :not_found
  end

  test "unauthenticated user is redirected to login" do
    sign_out @user
    get settings_tokens_path

    assert_response :redirect
    assert_redirected_to new_user_session_path
  end
end
