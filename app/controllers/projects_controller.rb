class ProjectsController < ApplicationController
  before_action :set_project, only: [ :show, :settings ]
  before_action :require_owner, only: :settings

  def index
    projects = current_user.projects.includes(:owner).order(updated_at: :desc)
    render inertia: "Projects/Index", props: {
      projects: projects.map { |p| serialize_project(p) }
    }
  end

  def show
    files = GitService.list_files(@project)
    render inertia: "Projects/Show", props: {
      project: serialize_project(@project),
      files: files
    }
  end

  def settings
    members = @project.memberships.includes(:user).order(:created_at)
    render inertia: "Projects/Settings", props: {
      project: serialize_project(@project),
      members: members.map { |m| serialize_membership(m) }
    }
  end

  def create
    project = Project.new(name: params[:name], slug: params[:name].to_s.parameterize, owner: current_user)

    Project.transaction do
      project.save!
      ProjectMembership.create!(user: current_user, project: project, role: "owner")
      GitService.init_repo(project)
    end

    redirect_to project_path(project.slug), notice: "Project created."
  rescue ActiveRecord::RecordInvalid
    redirect_back fallback_location: projects_path, inertia: { errors: project.errors.to_hash }
  rescue StandardError
    # Rollback can't undo filesystem side effects.
    GitService.delete_repo(project)
    redirect_back fallback_location: projects_path, alert: "Failed to create project."
  end

  private

  def set_project
    @project = current_user.projects.find_by!(slug: params[:slug])
  end

  def require_owner
    membership = @project.memberships.find_by(user: current_user)
    return if membership&.role == "owner"

    redirect_to project_path(@project.slug), alert: "Only project owners can manage settings."
  end

  def serialize_membership(membership)
    {
      id: membership.id,
      userName: membership.user.name,
      userEmail: membership.user.email,
      role: membership.role,
      createdAt: membership.created_at
    }
  end

  def clone_url_for(project)
    "#{request.protocol}#{request.host_with_port}/git/#{project.slug}.git"
  end

  def serialize_project(project)
    membership = project.memberships.find_by(user: current_user)
    {
      id: project.id,
      name: project.name,
      slug: project.slug,
      uuid: project.uuid,
      role: membership&.role,
      ownerId: project.owner.id,
      ownerName: project.owner.name,
      updatedAt: project.updated_at,
      cloneUrl: clone_url_for(project)
    }
  end
end
