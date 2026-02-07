Rails.application.configure do
  config.good_job.execution_mode = :async
  config.good_job.queues = "default:5"
  config.good_job.max_threads = 5
  config.good_job.poll_interval = 5
  config.good_job.shutdown_timeout = 25
  config.good_job.enable_cron = true

  config.good_job.cron = {
    cleanup_stale_ydocs: {
      cron: "*/15 * * * *",
      class: "CleanupStaleYdocsJob",
      description: "Clean up Y.js documents with no active connections"
    }
  }
end
