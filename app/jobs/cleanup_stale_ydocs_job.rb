class CleanupStaleYdocsJob < ApplicationJob
  queue_as :default

  def perform
    active_keys = Rails.cache.read("active_ydocs") || Set.new
    all_keys = Rails.cache.read("all_ydoc_keys") || Set.new

    stale_keys = all_keys - active_keys

    stale_keys.each do |cache_key|
      project_id, file_path = parse_cache_key(cache_key)
      next unless project_id

      FlushYdocToGitJob.perform_now(project_id, file_path)
      Rails.cache.delete(cache_key)
    end

    # Update registry to remove stale keys
    if stale_keys.any?
      Rails.cache.write("all_ydoc_keys", all_keys - stale_keys)
    end
  end

  private

  def parse_cache_key(key)
    # key format: "ydoc:<project_id>:<file_path>"
    parts = key.to_s.split(":", 3)
    return nil unless parts.length == 3 && parts[0] == "ydoc"

    [ parts[1].to_i, parts[2] ]
  end
end
