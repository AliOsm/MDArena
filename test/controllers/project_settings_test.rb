require "test_helper"

class ProjectSettingsTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @project = projects(:alpha)
  end

  test "owner can view settings page" do
    sign_in @alice
    get settings_project_path(@project.slug)

    assert_response :success
  end

  test "non-owner editor is redirected away" do
    sign_in @bob
    get settings_project_path(@project.slug)

    assert_redirected_to project_path(@project.slug)
  end

  test "non-member gets 404" do
    sign_in users(:admin)
    get settings_project_path(@project.slug)

    assert_response :not_found
  end

  test "unauthenticated user is redirected to login" do
    get settings_project_path(@project.slug)

    assert_redirected_to new_user_session_path
  end
end
