require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid user with all attributes" do
    user = User.new(name: "Test User", email: "test@example.com", password: "password123")

    assert_predicate user, :valid?
  end

  test "invalid without name" do
    user = User.new(name: nil, email: "test@example.com", password: "password123")

    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "invalid without email" do
    user = User.new(name: "Test", email: nil, password: "password123")

    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "invalid without password" do
    user = User.new(name: "Test", email: "test@example.com", password: nil)

    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "invalid with duplicate email" do
    user = User.new(name: "Test", email: users(:alice).email, password: "password123")

    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "invalid with short password" do
    user = User.new(name: "Test", email: "new@example.com", password: "short")

    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 6 characters)"
  end

  test "has all required devise modules" do
    expected = %i[database_authenticatable registerable recoverable rememberable validatable]

    assert_equal expected, expected & User.devise_modules
  end
end
