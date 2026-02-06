require "test_helper"

class FlushYdocToGitJobTest < ActiveSupport::TestCase
  setup do
    @project = projects(:alpha)
    @file_path = "readme.md"
    @cache_key = "ydoc:#{@project.id}:#{@file_path}"

    GitService.init_repo(@project)
  end

  teardown do
    FileUtils.rm_rf(GitService.repo_path(@project))
    FileUtils.rm_f("#{GitService.repo_path(@project)}.lock")
  end

  test "flush creates a Git commit from cached Y.js state" do
    doc = Y::Doc.new
    text = doc.get_text("content")
    text.insert(0, "# Hello World\n")
    Rails.cache.write(@cache_key, doc.full_diff, expires_in: 2.hours)

    FlushYdocToGitJob.perform_now(@project.id, @file_path)

    content = GitService.read_file(@project, @file_path)

    assert_equal "# Hello World\n", content
  end

  test "flush skips commit when content matches existing file" do
    user = users(:alice)
    GitService.commit_file(
      project: @project, path: @file_path,
      content: "existing content", user: user, message: "initial"
    )

    doc = Y::Doc.new
    text = doc.get_text("content")
    text.insert(0, "existing content")
    Rails.cache.write(@cache_key, doc.full_diff, expires_in: 2.hours)

    history_before = GitService.file_history(@project, @file_path)
    FlushYdocToGitJob.perform_now(@project.id, @file_path)
    history_after = GitService.file_history(@project, @file_path)

    assert_equal history_before.length, history_after.length
  end

  test "flush returns early when cache state is nil" do
    Rails.cache.delete(@cache_key)

    assert_nothing_raised do
      FlushYdocToGitJob.perform_now(@project.id, @file_path)
    end

    assert_raises(GitService::FileNotFoundError) do
      GitService.read_file(@project, @file_path)
    end
  end

  test "concurrency key is set correctly" do
    job = FlushYdocToGitJob.new(@project.id, @file_path)

    assert_equal "flush_ydoc:#{@project.id}:#{@file_path}", job.good_job_concurrency_key
  end

  test "flush creates commit for new file not in Git" do
    doc = Y::Doc.new
    text = doc.get_text("content")
    text.insert(0, "brand new file")
    Rails.cache.write(@cache_key, doc.full_diff, expires_in: 2.hours)

    FlushYdocToGitJob.perform_now(@project.id, @file_path)

    content = GitService.read_file(@project, @file_path)

    assert_equal "brand new file", content
  end

  test "flush commit uses Auto-save message" do
    doc = Y::Doc.new
    text = doc.get_text("content")
    text.insert(0, "some content")
    Rails.cache.write(@cache_key, doc.full_diff, expires_in: 2.hours)

    FlushYdocToGitJob.perform_now(@project.id, @file_path)

    history = GitService.file_history(@project, @file_path)

    assert_equal "Auto-save #{@file_path}", history.first[:message]
  end
end
