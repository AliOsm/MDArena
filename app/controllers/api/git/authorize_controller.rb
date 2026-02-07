module Api
  module Git
    class AuthorizeController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :verify_authenticity_token

      rate_limit to: 60, within: 1.minute

      def show
        email, password = extract_basic_auth_credentials
        return head :unauthorized unless email && password

        user = User.find_by(email: email)
        return head :unauthorized unless user

        return head :unauthorized unless user.valid_password?(password)

        project = find_project_from_uri
        return head :bad_request unless project

        return head :forbidden unless project.users.include?(user)

        if push_request?
          membership = project.memberships.find_by(user: user)
          return head :forbidden unless membership.role.in?(%w[owner editor])
        end

        response.headers["X-Repo-UUID"] = project.uuid
        head :ok
      end

      private

      def extract_basic_auth_credentials
        auth_header = request.headers["Authorization"]
        return [ nil, nil ] unless auth_header&.start_with?("Basic ")

        decoded = Base64.decode64(auth_header.delete_prefix("Basic "))
        email, password = decoded.split(":", 2)
        [ email, password ]
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
