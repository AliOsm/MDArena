require "test_helper"

class FilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:alice)
    sign_in @user
    @project = projects(:alpha)
    GitService.init_repo(@project)
    GitService.commit_file(
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

  # -- show --

  test "show renders file content" do
    get project_file_path(@project.slug, "readme.md")

    assert_response :success
  end

  test "show returns 404 for missing file" do
    get project_file_path(@project.slug, "missing.md")

    assert_response :not_found
  end

  test "show returns 404 for non-member project" do
    other_project = projects(:beta)
    GitService.init_repo(other_project)

    get project_file_path(other_project.slug, "readme.md")

    assert_response :not_found
  ensure
    FileUtils.rm_rf(GitService.repo_path(other_project))
  end

  # -- edit --

  test "edit renders file content for editing" do
    get project_edit_file_path(@project.slug, "readme.md")

    assert_response :success
  end

  # -- update --

  test "update commits file changes and redirects" do
    head_sha = Rugged::Repository.new(GitService.repo_path(@project)).references["refs/heads/main"].target.oid

    patch project_file_path(@project.slug, "readme.md"), params: {
      content: "# Updated\n",
      commit_message: "Update readme",
      base_commit_sha: head_sha
    }

    assert_redirected_to project_file_path(@project.slug, "readme.md")
    assert_equal "# Updated\n", GitService.read_file(@project, "readme.md")
  end

  test "update redirects back with alert on stale commit" do
    patch project_file_path(@project.slug, "readme.md"), params: {
      content: "# Stale\n",
      commit_message: "Stale update",
      base_commit_sha: "0000000000000000000000000000000000000000"
    }

    assert_response :redirect
    assert_equal "# Hello\n", GitService.read_file(@project, "readme.md")
  end

  # -- create --

  test "create commits a new file and redirects to project" do
    post project_files_path(@project.slug), params: { path: "hello.md", content: "# Hello\n" }

    assert_redirected_to project_path(@project.slug)
    assert_includes GitService.list_files(@project), "hello.md"
  end

  test "create auto-appends .md extension" do
    post project_files_path(@project.slug), params: { path: "readme2", content: "# Readme\n" }

    assert_redirected_to project_path(@project.slug)
    assert_includes GitService.list_files(@project), "readme2.md"
  end

  # -- destroy --

  test "destroy deletes file and redirects to project" do
    delete project_destroy_file_path(@project.slug, "readme.md")

    assert_redirected_to project_path(@project.slug)
    assert_empty GitService.list_files(@project)
  end

  # -- download_md --

  test "download_md sends markdown file as attachment" do
    get project_download_md_file_path(@project.slug, "readme.md")

    assert_response :success
    assert_equal "# Hello\n", response.body
    assert_match "attachment", response.headers["Content-Disposition"]
  end

  # -- download_pdf --

  test "download_pdf enqueues PdfExportJob and redirects" do
    assert_enqueued_with(job: PdfExportJob) do
      post project_download_pdf_file_path(@project.slug, "readme.md")
    end

    assert_response :redirect
  end

  # -- auth --

  test "actions require authentication" do
    sign_out @user
    get project_file_path(@project.slug, "readme.md")

    assert_response :redirect
  end
end
