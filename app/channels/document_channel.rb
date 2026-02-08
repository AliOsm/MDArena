class DocumentChannel < ApplicationCable::Channel
  ACTIVE_SUBSCRIBER_TTL = 5.minutes

  periodically :check_head_changed, every: 10.seconds

  def subscribed
    @project = Project.find_by(id: params[:project_id])

    unless @project && @project.memberships.exists?(user_id: current_user.id)
      reject
      return
    end

    @file_path = params[:file_path].to_s
    @stream_name = "document:#{@project.id}:#{@file_path}"
    @cache_key = "ydoc:#{@project.id}:#{@file_path}"
    @active_count_key = "ydoc_active_count:#{@project.id}:#{@file_path}"
    @last_edit_at_key = "ydoc_last_edit_at:#{@project.id}:#{@file_path}"
    @git_head_key = "ydoc_git_head:#{@project.id}:#{@file_path}"
    @flush_head_key = "last_flush_head:#{@project.id}:#{@file_path}"

    @last_known_head = GitService.head_sha(@project)

    stream_from @stream_name
    register_active_ydoc

    active_count = Rails.cache.read(@active_count_key).to_i
    state = YdocLock.with_lock(@project.id, @file_path) do
      load_or_init_ydoc(current_head: @last_known_head, active_count: active_count)
    end
    encoded = Base64.strict_encode64(state.pack("C*"))
    transmit({ type: "sync", state: encoded })
  end

  def receive(data)
    case data["type"]
    when "update"
      handle_update(data)
    when "awareness"
      ActionCable.server.broadcast(@stream_name, {
        type: "awareness",
        update: data["update"],
        sender: data["sender"]
      })
    when "save"
      flush_ydoc_to_git
      transmit({ type: "saved" })
    end
  end

  def unsubscribed
    return unless @project && @active_count_key

    remaining = deregister_active_ydoc
    FlushYdocToGitJob.set(wait: 5.seconds).perform_later(@project.id, @file_path) if remaining <= 0
  end

  def check_head_changed
    return unless @project

    refresh_active_subscriber_ttl

    current_head = GitService.head_sha(@project)
    return if current_head.nil? || current_head == @last_known_head

    @last_known_head = current_head

    # Skip broadcasting if this HEAD change was from a ydoc flush (not an external change)
    last_flush_head = Rails.cache.read(@flush_head_key)
    return if last_flush_head == current_head

    # Invalidate stale Y.js cache so refresh loads fresh content from git
    Rails.cache.delete(@cache_key)
    Rails.cache.delete(@last_edit_at_key)
    Rails.cache.delete(@git_head_key)

    ActionCable.server.broadcast(@stream_name, { type: "file_changed" })
  end

  private

  def register_active_ydoc
    # Track active subscribers with an atomic counter so multiple concurrent editors
    # don't clobber each other.
    Rails.cache.increment(@active_count_key, 1, initial: 0, expires_in: ACTIVE_SUBSCRIBER_TTL)

    YdocLock.with_registry_lock do
      all_keys = Rails.cache.read("all_ydoc_keys") || Set.new
      all_keys.add(@cache_key)
      Rails.cache.write("all_ydoc_keys", all_keys)
    end
  end

  def deregister_active_ydoc
    remaining = Rails.cache.decrement(@active_count_key, 1, initial: 0, expires_in: ACTIVE_SUBSCRIBER_TTL).to_i
    if remaining <= 0
      Rails.cache.delete(@active_count_key)
      0
    else
      remaining
    end
  end

  def handle_update(data)
    update_bytes = Base64.strict_decode64(data["update"]).unpack("C*")

    YdocLock.with_lock(@project.id, @file_path) do
      # Load current state, apply update, write back
      cached = Rails.cache.read(@cache_key)
      doc = Y::Doc.new
      doc.sync(cached) if cached
      doc.sync(update_bytes)

      Rails.cache.write(@cache_key, doc.full_diff, expires_in: 2.hours)
      Rails.cache.write(@last_edit_at_key, Time.current.to_f, expires_in: 2.hours)
    end

    # Broadcast to all subscribers with sender ID
    ActionCable.server.broadcast(@stream_name, {
      type: "update",
      update: data["update"],
      sender: data["sender"]
    })

    # Enqueue flush with 30-second delay
    FlushYdocToGitJob.set(wait: 30.seconds).perform_later(@project.id, @file_path)
  end

  def flush_ydoc_to_git
    YdocLock.with_lock(@project.id, @file_path) do
      cached_state = Rails.cache.read(@cache_key)
      return unless cached_state

      doc = Y::Doc.new
      doc.sync(cached_state)
      content = doc.get_text("content").to_s

      existing_content = begin
        GitService.read_file(@project, @file_path)
      rescue GitService::FileNotFoundError
        nil
      end

      return if content == existing_content

      GitService.commit_file(
        project: @project,
        path: @file_path,
        content: content,
        user: current_user,
        message: "Save #{@file_path}"
      )

      new_head = GitService.head_sha(@project)
      Rails.cache.write(@flush_head_key, new_head, expires_in: 60.seconds)
      Rails.cache.write(@git_head_key, new_head, expires_in: 2.hours) if new_head
      @last_known_head = new_head
    end
  end

  def load_or_init_ydoc(current_head:, active_count:)
    cached = Rails.cache.read(@cache_key)
    if cached
      cached_git_head = Rails.cache.read(@git_head_key)
      if active_count.to_i <= 1 && current_head.present? && cached_git_head.to_s != current_head.to_s
        Rails.cache.delete(@cache_key)
        Rails.cache.delete(@last_edit_at_key)
        Rails.cache.delete(@git_head_key)
      else
        return cached
      end
    end

    content = begin
      GitService.read_file(@project, @file_path)
    rescue GitService::FileNotFoundError
      ""
    end

    doc = Y::Doc.new
    text = doc.get_text("content")
    text.insert(0, content) unless content.empty?

    state = doc.full_diff
    Rails.cache.write(@cache_key, state, expires_in: 2.hours)
    Rails.cache.write(@git_head_key, current_head, expires_in: 2.hours) if current_head.present?

    state
  end

  def refresh_active_subscriber_ttl
    count = Rails.cache.read(@active_count_key)
    return if count.nil?

    Rails.cache.write(@active_count_key, count, expires_in: ACTIVE_SUBSCRIBER_TTL)
  end
end
