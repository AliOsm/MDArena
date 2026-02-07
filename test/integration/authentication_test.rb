require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "unauthenticated request redirects to login" do
    get "/"

    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "login page is accessible without authentication" do
    get new_user_session_path

    assert_response :success
  end

  test "signup page is accessible without authentication" do
    get new_user_registration_path

    assert_response :success
  end

  test "user can sign in with valid credentials" do
    post user_session_path, params: {
      user: { email: users(:alice).email, password: "password123" }
    }

    assert_response :redirect
    follow_redirect!

    # Root redirects to projects
    assert_response :redirect
    follow_redirect!

    assert_response :success
  end

  test "user cannot sign in with invalid password" do
    post user_session_path, params: {
      user: { email: users(:alice).email, password: "wrongpassword" }
    }

    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "user can sign out via DELETE /logout" do
    sign_in users(:alice)
    delete logout_path

    assert_response :redirect
  end

  test "user can register with valid attributes" do
    assert_difference("User.count", 1) do
      post user_registration_path, params: {
        user: { name: "New User", email: "new@example.com", password: "password123", password_confirmation: "password123" }
      }
    end
    assert_response :redirect
  end

  test "user cannot register without name" do
    assert_no_difference("User.count") do
      post user_registration_path, params: {
        user: { name: "", email: "new@example.com", password: "password123", password_confirmation: "password123" }
      }
    end
    assert_response :redirect
    assert_redirected_to new_user_registration_path
  end
end
