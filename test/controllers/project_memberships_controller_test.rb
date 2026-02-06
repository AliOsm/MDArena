require "test_helper"

class ProjectMembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @admin = users(:admin)
    @project = projects(:alpha)
    sign_in @alice
  end

  test "owner can add a member by email" do
    assert_difference("ProjectMembership.count", 1) do
      post project_memberships_path(@project.slug), params: { email: @admin.email, role: "editor" }
    end

    assert_redirected_to settings_project_path(@project.slug)
    assert_equal "editor", @project.memberships.find_by(user: @admin).role
  end

  test "add member with owner role" do
    post project_memberships_path(@project.slug), params: { email: @admin.email, role: "owner" }

    assert_redirected_to settings_project_path(@project.slug)
    assert_equal "owner", @project.memberships.find_by(user: @admin).role
  end

  test "add member with unknown email shows error" do
    assert_no_difference("ProjectMembership.count") do
      post project_memberships_path(@project.slug), params: { email: "nobody@example.com", role: "editor" }
    end

    assert_redirected_to settings_project_path(@project.slug)
  end

  test "add duplicate member shows error" do
    assert_no_difference("ProjectMembership.count") do
      post project_memberships_path(@project.slug), params: { email: @bob.email, role: "editor" }
    end

    assert_redirected_to settings_project_path(@project.slug)
  end

  test "owner can remove a member" do
    membership = project_memberships(:bob_alpha_editor)

    assert_difference("ProjectMembership.count", -1) do
      delete project_membership_path(@project.slug, membership)
    end

    assert_redirected_to settings_project_path(@project.slug)
  end

  test "owner cannot remove themselves" do
    membership = project_memberships(:alice_alpha_owner)

    assert_no_difference("ProjectMembership.count") do
      delete project_membership_path(@project.slug, membership)
    end

    assert_redirected_to settings_project_path(@project.slug)
  end

  test "non-owner cannot add members" do
    sign_in @bob

    assert_no_difference("ProjectMembership.count") do
      post project_memberships_path(@project.slug), params: { email: @admin.email, role: "editor" }
    end

    assert_redirected_to project_path(@project.slug)
  end

  test "non-owner cannot remove members" do
    sign_in @bob
    membership = project_memberships(:alice_alpha_owner)

    assert_no_difference("ProjectMembership.count") do
      delete project_membership_path(@project.slug, membership)
    end

    assert_redirected_to project_path(@project.slug)
  end

  test "unauthenticated user is redirected to login" do
    sign_out @alice
    post project_memberships_path(@project.slug), params: { email: @admin.email, role: "editor" }

    assert_redirected_to new_user_session_path
  end
end
