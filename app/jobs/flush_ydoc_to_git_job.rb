class FlushYdocToGitJob < ApplicationJob
  queue_as :default

  def perform(project_id, file_path)
    # Full implementation in US-035
  end
end
