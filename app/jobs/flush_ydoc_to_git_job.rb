class FlushYdocToGitJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  queue_as :default

  good_job_control_concurrency_with(
    key: -> { "flush_ydoc:#{arguments[0]}:#{arguments[1]}" },
    total_limit: 1
  )

  def perform(project_id, file_path)
    cache_key = "ydoc:#{project_id}:#{file_path}"
    cached_state = Rails.cache.read(cache_key)
    return if cached_state.nil?

    project = Project.find(project_id)

    doc = Y::Doc.new
    doc.sync(cached_state)
    content = doc.get_text("content").to_s

    # Skip commit if content matches existing file
    existing_content = begin
      GitService.read_file(project, file_path)
    rescue GitService::FileNotFoundError
      nil
    end

    return if content == existing_content

    auto_save_user = project.owner
    GitService.commit_file(
      project: project,
      path: file_path,
      content: content,
      user: auto_save_user,
      message: "Auto-save #{file_path}"
    )

    # Store the new HEAD so check_head_changed knows this was a flush, not an external change
    flush_head_key = "last_flush_head:#{project_id}:#{file_path}"
    Rails.cache.write(flush_head_key, GitService.head_sha(project), expires_in: 60.seconds)
  end
end
