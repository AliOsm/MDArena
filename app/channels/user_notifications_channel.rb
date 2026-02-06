class UserNotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "user:#{current_user.id}:notifications"
  end
end
