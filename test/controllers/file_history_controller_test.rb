require "test_helper"

class FileHistoryControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:alice)
    sign_in @user
    @project = projects(:alpha)
    GitService.init_repo(@project)
    @commit_sha = GitService.commit_file(
      project: @project,
      path: "readme.md",
      content: "# Hello\n",
      user: @user,
      message: "Initial commit"
    )
  end

  teardown do
    FileUtils.rm_rf(GitService.repo_path(@project))
    FileUtils.rm_rf("#{GitService.repo_path(@project)}.lock")
  end

  # -- index --

  test "index renders file history" do
    get project_file_history_path(@project.slug, "readme.md")

    assert_response :success
  end

  test "index returns history entries for a file with multiple commits" do
    GitService.commit_file(
      project: @project,
      path: "readme.md",
      content: "# Updated\n",
      user: @user,
      message: "Update readme"
    )

    get project_file_history_path(@project.slug, "readme.md")

    assert_response :success
  end

  test "index returns 404 for non-member project" do
    other_project = projects(:beta)
    GitService.init_repo(other_project)

    get project_file_history_path(other_project.slug, "readme.md")

    assert_response :not_found
  ensure
    FileUtils.rm_rf(GitService.repo_path(other_project))
  end

  # -- show --

  test "show renders file content at specific commit" do
    get project_file_history_show_path(@project.slug, "readme.md", @commit_sha)

    assert_response :success
  end

  test "show returns 404 for invalid commit SHA" do
    get project_file_history_show_path(@project.slug, "readme.md", "0000000000000000000000000000000000000000")

    assert_response :not_found
  end

  test "show returns 404 for file not present at commit" do
    new_sha = GitService.commit_file(
      project: @project,
      path: "other.md",
      content: "# Other\n",
      user: @user,
      message: "Add other"
    )

    get project_file_history_show_path(@project.slug, "readme.md", new_sha)

    assert_response :success
  end

  # -- auth --

  test "actions require authentication" do
    sign_out @user
    get project_file_history_path(@project.slug, "readme.md")

    assert_response :redirect
  end
end
