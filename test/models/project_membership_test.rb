require "test_helper"

class ProjectMembershipTest < ActiveSupport::TestCase
  test "valid membership" do
    membership = project_memberships(:alice_alpha_owner)

    assert_predicate membership, :valid?
  end

  test "validates role inclusion" do
    membership = project_memberships(:alice_alpha_owner)
    membership.role = "viewer"

    assert_not_predicate membership, :valid?
    assert_includes membership.errors[:role], "is not included in the list"
  end

  test "allows owner role" do
    membership = project_memberships(:alice_alpha_owner)

    assert_equal "owner", membership.role
    assert_predicate membership, :valid?
  end

  test "allows editor role" do
    membership = project_memberships(:bob_alpha_editor)

    assert_equal "editor", membership.role
    assert_predicate membership, :valid?
  end

  test "enforces uniqueness of user per project" do
    duplicate = ProjectMembership.new(user: users(:alice), project: projects(:alpha), role: "editor")

    assert_not_predicate duplicate, :valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "belongs to user" do
    membership = project_memberships(:alice_alpha_owner)

    assert_equal users(:alice), membership.user
  end

  test "belongs to project" do
    membership = project_memberships(:alice_alpha_owner)

    assert_equal projects(:alpha), membership.project
  end
end
