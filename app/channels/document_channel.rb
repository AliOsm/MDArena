class DocumentChannel < ApplicationCable::Channel
  def subscribed
    @project = Project.find_by(id: params[:project_id])

    unless @project && @project.users.include?(current_user)
      reject
      return
    end

    @file_path = params[:file_path]
    @stream_name = "document:#{@project.id}:#{@file_path}"
    @cache_key = "ydoc:#{@project.id}:#{@file_path}"

    stream_from @stream_name

    state = load_or_init_ydoc
    encoded = Base64.strict_encode64(state.pack("C*"))
    transmit({ type: "sync", state: encoded })
  end

  def unsubscribed
    # Cleanup handled in US-034
  end

  private

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
