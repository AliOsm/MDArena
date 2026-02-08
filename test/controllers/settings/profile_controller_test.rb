require "test_helper"

class Settings::ProfileControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:alice)
    sign_in @user
  end

  test "show renders profile page with user data" do
    get settings_profile_path

    assert_response :success
  end

  test "update changes user name" do
    patch settings_profile_path, params: { name: "Alice Updated" }

    assert_redirected_to settings_profile_path
    assert_equal "Alice Updated", @user.reload.name
  end

  test "update changes user email" do
    patch settings_profile_path, params: { name: @user.name, email: "newalice@example.com", current_password: "password123" }

    assert_redirected_to settings_profile_path
    assert_equal "newalice@example.com", @user.reload.email
  end

  test "update with email change requires current password" do
    original_email = @user.email

    patch settings_profile_path, params: { name: @user.name, email: "newalice@example.com" }

    assert_redirected_to settings_profile_path
    assert_equal original_email, @user.reload.email
  end

  test "update with password change requires current password" do
    patch settings_profile_path, params: {
      name: @user.name,
      password: "newpassword456",
      password_confirmation: "newpassword456"
    }

    assert_redirected_to settings_profile_path
    assert @user.reload.valid_password?("password123"), "Password should not have changed without current_password"
  end

  test "update changes password when current password is correct" do
    patch settings_profile_path, params: {
      name: @user.name,
      current_password: "password123",
      password: "newpassword456",
      password_confirmation: "newpassword456"
    }

    assert_redirected_to settings_profile_path
    assert @user.reload.valid_password?("newpassword456")
  end

  test "update rejects mismatched password confirmation" do
    patch settings_profile_path, params: {
      name: @user.name,
      current_password: "password123",
      password: "newpassword456",
      password_confirmation: "wrongconfirmation"
    }

    assert_redirected_to settings_profile_path
    assert @user.reload.valid_password?("password123"), "Password should not have changed"
  end

  test "update rejects blank name" do
    patch settings_profile_path, params: { name: "" }

    assert_redirected_to settings_profile_path
    assert_equal "Alice Smith", @user.reload.name
  end

  test "settings redirect goes to profile" do
    get "/settings"

    assert_redirected_to "/settings/profile"
  end

  test "unauthenticated user is redirected to login" do
    sign_out @user
    get settings_profile_path

    assert_redirected_to new_user_session_path
  end
end
