require "test_helper"

WardenStub = Struct.new(:user)

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "authenticated user connects successfully" do
    user = users(:alice)
    connect env: { "warden" => WardenStub.new(user) }

    assert_equal user, connection.current_user
  end

  test "unauthenticated connection is rejected" do
    assert_reject_connection do
      connect env: { "warden" => WardenStub.new(nil) }
    end
  end
end
