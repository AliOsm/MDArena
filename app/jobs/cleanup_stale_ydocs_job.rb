class CleanupStaleYdocsJob < ApplicationJob
  queue_as :default

  def perform
    all_keys = Rails.cache.read("all_ydoc_keys") || Set.new

    stale_keys = Set.new

    all_keys.each do |cache_key|
      parsed = parse_cache_key(cache_key)
      next unless parsed

      project_id, file_path = parsed
      active_count = Rails.cache.read(active_count_key(project_id, file_path)).to_i
      next if active_count > 0

      FlushYdocToGitJob.perform_now(project_id, file_path)
      Rails.cache.delete(cache_key)
      Rails.cache.delete(active_count_key(project_id, file_path))
      Rails.cache.delete(last_edit_at_key(project_id, file_path))
      Rails.cache.delete(git_head_key(project_id, file_path))
      stale_keys.add(cache_key)
    end

    # Update registry to remove stale keys without clobbering concurrent additions.
    return if stale_keys.empty?

    YdocLock.with_registry_lock do
      current_keys = Rails.cache.read("all_ydoc_keys") || Set.new
      stale_keys.each do |cache_key|
        parsed = parse_cache_key(cache_key)
        next unless parsed

        project_id, file_path = parsed

        # If a ydoc was re-created or editors reconnected since this cleanup began,
        # keep it in the registry.
        next if Rails.cache.read(cache_key)
        next if Rails.cache.read(active_count_key(project_id, file_path)).to_i > 0

        current_keys.delete(cache_key)
      end
      Rails.cache.write("all_ydoc_keys", current_keys)
    end
  end

  private

  def active_count_key(project_id, file_path)
    "ydoc_active_count:#{project_id}:#{file_path}"
  end

  def last_edit_at_key(project_id, file_path)
    "ydoc_last_edit_at:#{project_id}:#{file_path}"
  end

  def git_head_key(project_id, file_path)
    "ydoc_git_head:#{project_id}:#{file_path}"
  end

  def parse_cache_key(key)
    # key format: "ydoc:<project_id>:<file_path>"
    parts = key.to_s.split(":", 3)
    return nil unless parts.length == 3 && parts[0] == "ydoc"

    [ parts[1].to_i, parts[2] ]
  end
end
