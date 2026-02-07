class DocumentChannel < ApplicationCable::Channel
  periodically :check_head_changed, every: 10.seconds

  def subscribed
    @project = Project.find_by(id: params[:project_id])

    unless @project && @project.users.include?(current_user)
      reject
      return
    end

    @file_path = params[:file_path]
    @stream_name = "document:#{@project.id}:#{@file_path}"
    @cache_key = "ydoc:#{@project.id}:#{@file_path}"

    @last_known_head = GitService.head_sha(@project)

    stream_from @stream_name
    register_active_ydoc

    state = load_or_init_ydoc
    encoded = Base64.strict_encode64(state.pack("C*"))
    transmit({ type: "sync", state: encoded })
  end

  def receive(data)
    case data["type"]
    when "update"
      handle_update(data)
    when "save"
      flush_ydoc_to_git
      transmit({ type: "saved" })
    end
  end

  def unsubscribed
    return unless @project

    deregister_active_ydoc
    FlushYdocToGitJob.set(wait: 5.seconds).perform_later(@project.id, @file_path)
  end

  def check_head_changed
    return unless @project

    current_head = GitService.head_sha(@project)
    return if current_head.nil? || current_head == @last_known_head

    @last_known_head = current_head

    # Skip broadcasting if this HEAD change was from a ydoc flush (not an external change)
    flush_head_key = "last_flush_head:#{@project.id}:#{@file_path}"
    last_flush_head = Rails.cache.read(flush_head_key)
    return if last_flush_head == current_head

    # Invalidate stale Y.js cache so refresh loads fresh content from git
    Rails.cache.delete(@cache_key)

    ActionCable.server.broadcast(@stream_name, { type: "file_changed" })
  end

  private

  def register_active_ydoc
    active = Rails.cache.read("active_ydocs") || Set.new
    active.add(@cache_key)
    Rails.cache.write("active_ydocs", active)

    all_keys = Rails.cache.read("all_ydoc_keys") || Set.new
    all_keys.add(@cache_key)
    Rails.cache.write("all_ydoc_keys", all_keys)
  end

  def deregister_active_ydoc
    active = Rails.cache.read("active_ydocs") || Set.new
    active.delete(@cache_key)
    Rails.cache.write("active_ydocs", active)
  end

  def handle_update(data)
    update_bytes = Base64.strict_decode64(data["update"]).unpack("C*")

    # Load current state, apply update, write back
    cached = Rails.cache.read(@cache_key)
    doc = Y::Doc.new
    doc.sync(cached) if cached
    doc.sync(update_bytes)

    Rails.cache.write(@cache_key, doc.full_diff, expires_in: 2.hours)

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

    flush_head_key = "last_flush_head:#{@project.id}:#{@file_path}"
    Rails.cache.write(flush_head_key, GitService.head_sha(@project), expires_in: 60.seconds)
    @last_known_head = GitService.head_sha(@project)
  end

  def load_or_init_ydoc
    cached = Rails.cache.read(@cache_key)
    return cached if cached

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

    state
  end
end
