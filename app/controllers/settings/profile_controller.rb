module Settings
  class ProfileController < ApplicationController
    def show
      render inertia: "Settings/Profile", props: {
        user: serialize_user(current_user)
      }
    end

    def update
      if needs_password_change?
        success = current_user.update_with_password(profile_params)
      else
        success = current_user.update(profile_params.except(:current_password, :password, :password_confirmation))
      end

      if success
        bypass_sign_in(current_user)
        redirect_to settings_profile_path, notice: "Profile updated successfully."
      else
        redirect_to settings_profile_path, inertia: { errors: current_user.errors.to_hash(true) }
      end
    end

    private

    def profile_params
      params.permit(:name, :email, :current_password, :password, :password_confirmation)
    end

    def serialize_user(user)
      {
        name: user.name,
        email: user.email
      }
    end

    def needs_password_change?
      params[:password].present?
    end
  end
end
