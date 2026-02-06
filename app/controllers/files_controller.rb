class FilesController < ApplicationController
  before_action :set_project

  def create
    path = params[:path].to_s.strip
    path = "#{path}.md" unless path.end_with?(".md")
    content = params[:content].to_s

    GitService.commit_file(
      project: @project,
      path: path,
      content: content,
      user: current_user,
      message: "Create #{path}"
    )

    redirect_to project_path(@project.slug), notice: "File created."
  end

  private

  def set_project
    @project = current_user.projects.find_by!(slug: params[:project_slug])
  end
end
