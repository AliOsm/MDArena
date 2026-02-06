class ProjectMembershipsController < ApplicationController
  before_action :set_project
  before_action :require_owner

  def create
    user = User.find_by(email: params[:email])
    unless user
      redirect_to settings_project_path(@project.slug), alert: "User not found with that email."
      return
    end

    membership = @project.memberships.new(user: user, role: params[:role].presence || "editor")
    if membership.save
      redirect_to settings_project_path(@project.slug), notice: "Member added."
    else
      redirect_to settings_project_path(@project.slug), alert: membership.errors.full_messages.first
    end
  end

  def destroy
    membership = @project.memberships.find(params[:id])

    if membership.user_id == current_user.id
      redirect_to settings_project_path(@project.slug), alert: "You cannot remove yourself."
      return
    end

    membership.destroy
    redirect_to settings_project_path(@project.slug), notice: "Member removed."
  end

  private

  def set_project
    @project = current_user.projects.find_by!(slug: params[:project_slug])
  end

  def require_owner
    membership = @project.memberships.find_by(user: current_user)
    return if membership&.role == "owner"

    redirect_to project_path(@project.slug), alert: "Only project owners can manage settings."
  end
end
