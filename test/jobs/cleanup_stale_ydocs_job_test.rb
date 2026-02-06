require "test_helper"

class CleanupStaleYdocsJobTest < ActiveSupport::TestCase
  setup do
    @project = projects(:alpha)
    @user = users(:alice)
    @file_path = "readme.md"
    @cache_key = "ydoc:#{@project.id}:#{@file_path}"

    GitService.init_repo(@project)

    Rails.cache.clear
  end

  teardown do
    FileUtils.rm_rf(GitService.repo_path(@project))
    FileUtils.rm_f("#{GitService.repo_path(@project)}.lock")
    Rails.cache.clear
  end

  test "flushes and clears stale ydoc with no active subscribers" do
    # Create a cached ydoc state
    doc = Y::Doc.new
    text = doc.get_text("content")
    text.insert(0, "stale content")
    Rails.cache.write(@cache_key, doc.full_diff, expires_in: 2.hours)

    # Register it in the all_ydoc_keys registry but NOT in active_ydocs
    Rails.cache.write("all_ydoc_keys", Set.new([ @cache_key ]))
    Rails.cache.write("active_ydocs", Set.new)

    CleanupStaleYdocsJob.perform_now

    # Cache should be cleared
    assert_nil Rails.cache.read(@cache_key)

    # Content should be flushed to Git
    content = GitService.read_file(@project, @file_path)

    assert_equal "stale content", content
  end

  test "does not clean up ydocs with active subscribers" do
    # Create a cached ydoc state
    doc = Y::Doc.new
    text = doc.get_text("content")
    text.insert(0, "active content")
    state = doc.full_diff
    Rails.cache.write(@cache_key, state, expires_in: 2.hours)

    # Register it as active
    Rails.cache.write("all_ydoc_keys", Set.new([ @cache_key ]))
    Rails.cache.write("active_ydocs", Set.new([ @cache_key ]))

    CleanupStaleYdocsJob.perform_now

    # Cache should still exist
    assert_not_nil Rails.cache.read(@cache_key)
  end

  test "removes stale keys from all_ydoc_keys registry" do
    doc = Y::Doc.new
    doc.get_text("content").insert(0, "cleanup me")
    Rails.cache.write(@cache_key, doc.full_diff, expires_in: 2.hours)
    active_key = "ydoc:#{@project.id}:active.md"

    Rails.cache.write("all_ydoc_keys", Set.new([ @cache_key, active_key ]))
    Rails.cache.write("active_ydocs", Set.new([ active_key ]))

    CleanupStaleYdocsJob.perform_now

    remaining = Rails.cache.read("all_ydoc_keys")

    assert_includes remaining, active_key
    assert_not_includes remaining, @cache_key
  end

  test "handles empty registries gracefully" do
    assert_nothing_raised do
      CleanupStaleYdocsJob.perform_now
    end
  end
end
