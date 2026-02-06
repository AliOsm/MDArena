module Api
  module Git
    class AuthorizeController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :verify_authenticity_token

      def show
        email, token = extract_basic_auth_credentials
        return head :unauthorized unless email && token

        user = User.find_by(email: email)
        return head :unauthorized unless user

        pat = PersonalAccessToken.authenticate(token)
        return head :unauthorized unless pat&.user_id == user.id

        pat.update_column(:last_used_at, Time.current)

        project = find_project_from_uri
        return head :bad_request unless project

        return head :forbidden unless project.users.include?(user)

        if push_request?
          membership = project.memberships.find_by(user: user)
          return head :forbidden unless membership.role.in?(%w[owner editor])
        end

        head :ok
      end

      private

      def extract_basic_auth_credentials
        auth_header = request.headers["Authorization"]
        return [ nil, nil ] unless auth_header&.start_with?("Basic ")

        decoded = Base64.decode64(auth_header.delete_prefix("Basic "))
        email, token = decoded.split(":", 2)
        [ email, token ]
      end

      def find_project_from_uri
        original_uri = request.headers["X-Original-URI"]
        return nil unless original_uri

        match = original_uri.match(%r{/git/([^/]+)\.git/})
        return nil unless match

        Project.find_by(slug: match[1])
      end

      def push_request?
        original_uri = request.headers["X-Original-URI"].to_s
        original_uri.include?("git-receive-pack")
      end
    end
  end
end
