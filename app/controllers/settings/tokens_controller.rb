module Settings
  class TokensController < ApplicationController
    def index
      tokens = current_user.personal_access_tokens.order(created_at: :desc)
      render inertia: "Settings/Tokens", props: {
        tokens: tokens.map { |t| serialize_token(t) },
        newToken: flash[:new_token]
      }
    end

    def create
      token = current_user.personal_access_tokens.create!(name: params[:name])
      redirect_to settings_tokens_path, flash: { new_token: token.token }
    end

    def destroy
      token = current_user.personal_access_tokens.find(params[:id])
      token.revoke!
      redirect_to settings_tokens_path, notice: "Token revoked."
    end

    private

    def serialize_token(token)
      {
        id: token.id,
        name: token.name,
        tokenPrefix: token.token_prefix,
        lastUsedAt: token.last_used_at,
        expiresAt: token.expires_at,
        revokedAt: token.revoked_at,
        createdAt: token.created_at
      }
    end
  end
end
