require "test_helper"

class GitServiceTest < ActiveSupport::TestCase
  setup do
    @project = projects(:alpha)
    @user = users(:alice)
    @repo_path = GitService.repo_path(@project)
    FileUtils.rm_rf(@repo_path)
    FileUtils.rm_f("#{@repo_path}.lock")
  end

  teardown do
    FileUtils.rm_rf(@repo_path)
    FileUtils.rm_f("#{@repo_path}.lock")
  end

  test "repo_path returns correct path based on project uuid" do
    expected = File.join(Rails.configuration.repos_root, "#{@project.uuid}.git")

    assert_equal expected, GitService.repo_path(@project)
  end

  test "init_repo creates a bare repository" do
    repo = GitService.init_repo(@project)

    assert_predicate repo, :bare?
    assert Dir.exist?(@repo_path)
  end

  test "commit_file creates a commit with file content" do
    GitService.init_repo(@project)
    sha = GitService.commit_file(
      project: @project,
      path: "README.md",
      content: "# Hello World",
      user: @user,
      message: "Initial commit"
    )

    assert_match(/\A[0-9a-f]{40}\z/, sha)
  end

  test "read_file returns file content after commit" do
    GitService.init_repo(@project)
    GitService.commit_file(
      project: @project,
      path: "README.md",
      content: "# Hello World",
      user: @user,
      message: "Initial commit"
    )
    content = GitService.read_file(@project, "README.md")

    assert_equal "# Hello World", content
  end

  test "read_file raises FileNotFoundError for missing file" do
    GitService.init_repo(@project)
    GitService.commit_file(
      project: @project,
      path: "README.md",
      content: "# Hello",
      user: @user,
      message: "Initial commit"
    )
    assert_raises(GitService::FileNotFoundError) do
      GitService.read_file(@project, "nonexistent.md")
    end
  end

  test "read_file raises FileNotFoundError for empty repo" do
    GitService.init_repo(@project)
    assert_raises(GitService::FileNotFoundError) do
      GitService.read_file(@project, "README.md")
    end
  end

  test "list_files returns all file paths" do
    GitService.init_repo(@project)
    GitService.commit_file(project: @project, path: "README.md", content: "# Hello", user: @user, message: "Add readme")
    GitService.commit_file(project: @project, path: "docs/guide.md", content: "# Guide", user: @user, message: "Add guide")

    files = GitService.list_files(@project)

    assert_equal %w[README.md docs/guide.md].sort, files.sort
  end

  test "list_files returns empty array for empty repo" do
    GitService.init_repo(@project)

    assert_empty GitService.list_files(@project)
  end

  test "commit_file raises StaleCommitError when base_sha does not match HEAD" do
    GitService.init_repo(@project)
    GitService.commit_file(project: @project, path: "README.md", content: "v1", user: @user, message: "v1")
    old_sha = Rugged::Repository.new(@repo_path).references["refs/heads/main"].target.oid
    GitService.commit_file(project: @project, path: "README.md", content: "v2", user: @user, message: "v2")

    assert_raises(GitService::StaleCommitError) do
      GitService.commit_file(project: @project, path: "README.md", content: "v3", user: @user, message: "v3", base_sha: old_sha)
    end
  end

  test "commit_file succeeds when base_sha matches HEAD" do
    GitService.init_repo(@project)
    GitService.commit_file(project: @project, path: "README.md", content: "v1", user: @user, message: "v1")
    current_sha = Rugged::Repository.new(@repo_path).references["refs/heads/main"].target.oid

    sha = GitService.commit_file(project: @project, path: "README.md", content: "v2", user: @user, message: "v2", base_sha: current_sha)

    assert_match(/\A[0-9a-f]{40}\z/, sha)
    assert_equal "v2", GitService.read_file(@project, "README.md")
  end

  test "commit_file updates existing file content" do
    GitService.init_repo(@project)
    GitService.commit_file(project: @project, path: "README.md", content: "v1", user: @user, message: "v1")
    GitService.commit_file(project: @project, path: "README.md", content: "v2", user: @user, message: "v2")

    assert_equal "v2", GitService.read_file(@project, "README.md")
  end

  test "with_repo_lock creates lock file and provides exclusive access" do
    GitService.init_repo(@project)
    lock_path = "#{@repo_path}.lock"
    executed = false

    GitService.with_repo_lock(@project) do
      assert_path_exists lock_path
      executed = true
    end

    assert executed
  end
end
