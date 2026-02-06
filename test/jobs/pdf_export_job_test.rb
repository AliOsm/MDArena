require "test_helper"
require "ostruct"

class PdfExportJobTest < ActiveSupport::TestCase
  setup do
    @project = projects(:alpha)
    @user = users(:alice)
    @file_path = "readme.md"

    GitService.init_repo(@project)
    GitService.commit_file(
      project: @project,
      path: @file_path,
      content: "# Hello World\n\nSome **bold** text.",
      user: @user,
      message: "Initial commit"
    )
  end

  teardown do
    FileUtils.rm_rf(GitService.repo_path(@project))
    FileUtils.rm_f("#{GitService.repo_path(@project)}.lock")
  end

  test "creates PDF blob from markdown file" do
    fake_pdf = "%PDF-1.4 fake pdf content"
    original_new = Grover.method(:new)
    Grover.define_singleton_method(:new) { |*_args| OpenStruct.new(to_pdf: fake_pdf) }

    PdfExportJob.perform_now(@project.id, @file_path, @user.id)

    blob = ActiveStorage::Blob.last

    assert_equal "readme.pdf", blob.filename.to_s
    assert_equal "application/pdf", blob.content_type
  ensure
    Grover.define_singleton_method(:new, original_new)
  end

  test "broadcasts pdf_ready notification to user channel" do
    fake_pdf = "%PDF-1.4 fake pdf content"
    original_new = Grover.method(:new)
    Grover.define_singleton_method(:new) { |*_args| OpenStruct.new(to_pdf: fake_pdf) }

    notifications = []
    callback = ->(*args) {
      payload = args.last
      if payload[:broadcasting] == "user:#{@user.id}:notifications"
        notifications << payload[:message]
      end
    }

    ActiveSupport::Notifications.subscribed(callback, "broadcast.action_cable") do
      PdfExportJob.perform_now(@project.id, @file_path, @user.id)
    end

    assert_equal 1, notifications.length
    assert_equal({ type: "pdf_ready", filename: "readme.pdf" }, notifications.first.slice(:type, :filename))
  ensure
    Grover.define_singleton_method(:new, original_new)
  end

  test "job is queued on pdf_export queue" do
    job = PdfExportJob.new

    assert_equal "pdf_export", job.queue_name
  end
end
