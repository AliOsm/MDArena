require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:alice)
    sign_in @user
    @project = projects(:alpha)
  end

  test "index renders projects page" do
    get projects_path

    assert_response :success
  end

  test "index only shows projects the user is a member of" do
    # alice is member of alpha (owner) but not beta
    get projects_path

    assert_response :success
  end

  test "show renders project page with files" do
    GitService.init_repo(@project)

    get project_path(@project.slug)

    assert_response :success
  end

  test "show returns 404 for non-member project" do
    beta = projects(:beta)

    get project_path(beta.slug)

    assert_response :not_found
  end

  test "create creates project and redirects" do
    assert_difference([ "Project.count", "ProjectMembership.count" ], 1) do
      post projects_path, params: { name: "My New Project" }
    end

    assert_redirected_to project_path(Project.last.slug)
  end

  test "create sets correct project attributes and initializes git repo" do
    post projects_path, params: { name: "My New Project" }
    project = Project.last

    assert_equal({ name: "My New Project", slug: "my-new-project", owner_id: @user.id },
                 { name: project.name, slug: project.slug, owner_id: project.owner_id })
    assert_equal "owner", project.memberships.find_by(user: @user).role
    assert Dir.exist?(GitService.repo_path(project))
  end

  test "create fails with blank name" do
    assert_no_difference("Project.count") do
      post projects_path, params: { name: "" }
    end
  end

  test "unauthenticated user is redirected to login" do
    sign_out @user
    get projects_path

    assert_response :redirect
    assert_redirected_to new_user_session_path
  end
end
