class FileHistoryController < ApplicationController
  before_action :set_project
  before_action :set_file_path

  rescue_from GitService::FileNotFoundError, with: :file_not_found

  def index
    history = GitService.file_history(@project, @file_path)
    render inertia: "Files/History", props: {
      project: serialize_project,
      path: @file_path,
      history: history.map { |entry|
        {
          sha: entry[:sha],
          message: entry[:message],
          author: entry[:author],
          time: entry[:time].iso8601
        }
      }
    }
  end

  def show
    content = GitService.file_content_at(@project, @file_path, params[:sha])
    render inertia: "Files/HistoryShow", props: {
      project: serialize_project,
      path: @file_path,
      sha: params[:sha],
      content: content
    }
  end

  private

  def set_project
    @project = current_user.projects.find_by!(slug: params[:project_slug])
  end

  def set_file_path
    @file_path = params[:path]
  end

  def serialize_project
    {
      name: @project.name,
      slug: @project.slug,
      uuid: @project.uuid
    }
  end

  def file_not_found
    raise ActiveRecord::RecordNotFound
  end
end
