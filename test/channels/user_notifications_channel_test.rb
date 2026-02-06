require "test_helper"

class UserNotificationsChannelTest < ActionCable::Channel::TestCase
  setup do
    @user = users(:alice)
    stub_connection current_user: @user
  end

  test "subscribes and streams from user notifications" do
    subscribe

    assert_predicate subscription, :confirmed?
    assert_has_stream "user:#{@user.id}:notifications"
  end

  test "streams are scoped to the authenticated user" do
    other_user = users(:bob)
    stub_connection current_user: other_user

    subscribe

    assert_predicate subscription, :confirmed?
    assert_has_stream "user:#{other_user.id}:notifications"
  end
end
