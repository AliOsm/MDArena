class FilesController < ApplicationController
  before_action :set_project
  before_action :set_file_path, only: [ :show, :edit, :update, :destroy, :download_md, :download_pdf ]

  rescue_from GitService::FileNotFoundError, with: :file_not_found

  def show
    content = GitService.read_file(@project, @file_path)
    head_sha = head_sha_for(@project)
    render inertia: "Files/Show", props: {
      project: serialize_project,
      path: @file_path,
      content: content,
      headSha: head_sha
    }
  end

  def edit
    content = GitService.read_file(@project, @file_path)
    head_sha = head_sha_for(@project)
    render inertia: "Files/Edit", props: {
      project: serialize_project,
      path: @file_path,
      content: content,
      headSha: head_sha
    }
  end

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

  def update
    GitService.commit_file(
      project: @project,
      path: @file_path,
      content: params[:content].to_s,
      user: current_user,
      message: params[:commit_message].presence || "Update #{@file_path}",
      base_sha: params[:base_commit_sha]
    )

    redirect_to project_file_path(@project.slug, @file_path), notice: "File saved."
  rescue GitService::StaleCommitError
    redirect_back fallback_location: project_edit_file_path(@project.slug, @file_path),
                  alert: "The file was modified by someone else. Please refresh and try again."
  end

  def destroy
    GitService.delete_file(
      project: @project,
      path: @file_path,
      user: current_user,
      message: "Delete #{@file_path}"
    )

    redirect_to project_path(@project.slug), notice: "File deleted."
  end

  def download_md
    content = GitService.read_file(@project, @file_path)
    send_data content, filename: @file_path, type: "text/markdown", disposition: :attachment
  end

  def download_pdf
    PdfExportJob.perform_later(@project.id, @file_path, current_user.id)
    redirect_back fallback_location: project_file_path(@project.slug, @file_path),
                  notice: "PDF export started. You'll be notified when it's ready."
  end

  private

  def set_project
    @project = current_user.projects.find_by!(slug: params[:project_slug])
  end

  def set_file_path
    @file_path = params[:path]
  end

  def head_sha_for(project)
    repo = Rugged::Repository.new(GitService.repo_path(project))
    repo.references["refs/heads/main"]&.target&.oid
  rescue Rugged::RepositoryError
    nil
  end

  def serialize_project
    {
      id: @project.id,
      name: @project.name,
      slug: @project.slug,
      uuid: @project.uuid
    }
  end

  def file_not_found
    raise ActiveRecord::RecordNotFound
  end
end
