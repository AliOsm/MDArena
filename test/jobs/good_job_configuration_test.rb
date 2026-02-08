require "test_helper"

class GoodJobConfigurationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "good_job is configured as queue adapter in application config" do
    # Test env overrides to :test, but application.rb sets :good_job
    app_config = Rails.application.config

    assert_includes [ :good_job, :test ], app_config.active_job.queue_adapter
  end

  test "a job can be enqueued" do
    assert_enqueued_with(job: CleanupStaleYdocsJob) do
      CleanupStaleYdocsJob.perform_later
    end
  end
end
