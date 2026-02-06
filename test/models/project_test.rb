require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "valid project" do
    project = projects(:alpha)

    assert_predicate project, :valid?
  end

  test "requires name" do
    project = projects(:alpha)
    project.name = nil

    assert_not_predicate project, :valid?
    assert_includes project.errors[:name], "can't be blank"
  end

  test "requires slug" do
    project = projects(:alpha)
    project.slug = nil

    assert_not_predicate project, :valid?
    assert_includes project.errors[:slug], "can't be blank"
  end

  test "enforces slug uniqueness" do
    duplicate = Project.new(name: "Duplicate", slug: projects(:alpha).slug, owner: users(:bob))

    assert_not_predicate duplicate, :valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "belongs to owner" do
    project = projects(:alpha)

    assert_equal users(:alice), project.owner
  end

  test "has many memberships" do
    project = projects(:alpha)

    assert_equal 2, project.memberships.count
  end

  test "has many users through memberships" do
    project = projects(:alpha)

    assert_includes project.users, users(:alice)
    assert_includes project.users, users(:bob)
  end

  test "destroying project destroys memberships" do
    project = projects(:alpha)
    membership_ids = project.membership_ids

    assert_difference "ProjectMembership.count", -membership_ids.size do
      project.destroy
    end
  end
end
