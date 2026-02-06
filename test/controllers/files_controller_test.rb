require "test_helper"

class FilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:alice)
    sign_in @user
    @project = projects(:alpha)
    GitService.init_repo(@project)
  end

  test "create commits a new file and redirects to project" do
    post project_files_path(@project.slug), params: { path: "hello.md", content: "# Hello\n" }

    assert_redirected_to project_path(@project.slug)
    assert_includes GitService.list_files(@project), "hello.md"
  end

  test "create auto-appends .md extension" do
    post project_files_path(@project.slug), params: { path: "readme", content: "# Readme\n" }

    assert_redirected_to project_path(@project.slug)
    assert_includes GitService.list_files(@project), "readme.md"
  end

  test "create requires authentication" do
    sign_out @user
    post project_files_path(@project.slug), params: { path: "test.md", content: "test" }

    assert_response :redirect
    assert_redirected_to new_user_session_path
  end
end
