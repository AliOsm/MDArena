require "test_helper"

class DocumentChannelTest < ActionCable::Channel::TestCase
  setup do
    @project = projects(:alpha)
    @user = users(:alice)
    @file_path = "readme.md"

    # Initialize git repo and commit a file
    GitService.init_repo(@project)
    GitService.commit_file(
      project: @project,
      path: @file_path,
      content: "# Hello",
      user: @user,
      message: "Initial commit"
    )

    # Clear cache before each test
    Rails.cache.clear

    stub_connection current_user: @user
  end

  teardown do
    repo_path = GitService.repo_path(@project)
    FileUtils.rm_rf(repo_path)
    FileUtils.rm_f("#{repo_path}.lock")
    Rails.cache.clear
  end

  test "subscribes successfully with project membership" do
    subscribe(project_id: @project.id, file_path: @file_path)

    assert_predicate subscription, :confirmed?
    assert_has_stream "document:#{@project.id}:#{@file_path}"
  end

  test "rejects subscription for non-member" do
    non_member = users(:admin)
    stub_connection current_user: non_member

    subscribe(project_id: @project.id, file_path: @file_path)

    assert_predicate subscription, :rejected?
  end

  test "rejects subscription for invalid project" do
    subscribe(project_id: -1, file_path: @file_path)

    assert_predicate subscription, :rejected?
  end

  test "transmits initial sync state from git content" do
    subscribe(project_id: @project.id, file_path: @file_path)

    assert_predicate subscription, :confirmed?

    transmitted = transmissions.last

    assert_equal "sync", transmitted["type"]

    # Decode and verify the Y.js state contains the file content
    state_bytes = Base64.strict_decode64(transmitted["state"]).unpack("C*")
    doc = Y::Doc.new
    doc.sync(state_bytes)
    text = doc.get_text("content")

    assert_equal "# Hello", text.to_s
  end

  test "initializes empty ydoc for missing file" do
    subscribe(project_id: @project.id, file_path: "nonexistent.md")

    assert_predicate subscription, :confirmed?

    transmitted = transmissions.last

    assert_equal "sync", transmitted["type"]

    state_bytes = Base64.strict_decode64(transmitted["state"]).unpack("C*")
    doc = Y::Doc.new
    doc.sync(state_bytes)
    text = doc.get_text("content")

    assert_equal "", text.to_s
  end

  test "caches ydoc state with 2-hour TTL" do
    subscribe(project_id: @project.id, file_path: @file_path)

    cached = Rails.cache.read("ydoc:#{@project.id}:#{@file_path}")

    assert_not_nil cached
    assert_kind_of Array, cached
  end

  test "uses cached state on subsequent subscriptions" do
    # First subscription populates cache
    subscribe(project_id: @project.id, file_path: @file_path)
    unsubscribe

    # Modify file in Git (cache should still have old content)
    GitService.commit_file(
      project: @project,
      path: @file_path,
      content: "# Updated",
      user: @user,
      message: "Update"
    )

    # Second subscription should use cached state (not re-read from Git)
    subscribe(project_id: @project.id, file_path: @file_path)
    transmitted = transmissions.last
    state_bytes = Base64.strict_decode64(transmitted["state"]).unpack("C*")
    doc = Y::Doc.new
    doc.sync(state_bytes)
    text = doc.get_text("content")

    assert_equal "# Hello", text.to_s
  end
end
