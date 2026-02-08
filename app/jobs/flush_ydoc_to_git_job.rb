class FlushYdocToGitJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  queue_as :default

  good_job_control_concurrency_with(
    key: -> { "flush_ydoc:#{arguments[0]}:#{arguments[1]}" },
    total_limit: 1,
    enqueue_limit: 1
  )

  def perform(project_id, file_path)
    YdocLock.with_lock(project_id, file_path) do
      cache_key = "ydoc:#{project_id}:#{file_path}"
      cached_state = Rails.cache.read(cache_key)
      return if cached_state.nil?

      # If the document is actively being edited, debounce the flush so we commit
      # only after a period of inactivity.
      active_count = Rails.cache.read("ydoc_active_count:#{project_id}:#{file_path}").to_i
      if active_count > 0
        last_edit_at = Rails.cache.read("ydoc_last_edit_at:#{project_id}:#{file_path}")
        if last_edit_at
          seconds_since_last_edit = Time.current.to_f - last_edit_at.to_f
          if seconds_since_last_edit < 30
            delay = 30 - seconds_since_last_edit
            self.class.set(wait: [ delay, 1 ].max.seconds).perform_later(project_id, file_path)
            return
          end
        end
      end

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
      new_head = GitService.head_sha(project)
      flush_head_key = "last_flush_head:#{project_id}:#{file_path}"
      Rails.cache.write(flush_head_key, new_head, expires_in: 60.seconds)

      git_head_key = "ydoc_git_head:#{project_id}:#{file_path}"
      Rails.cache.write(git_head_key, new_head, expires_in: 2.hours) if new_head
    end
  end
end
