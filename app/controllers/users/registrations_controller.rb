class Users::RegistrationsController < Devise::RegistrationsController
  def new
    render inertia: "Auth/SignUp"
  end

  def create
    build_resource(sign_up_params)

    resource.save

    if resource.persisted?
      if resource.active_for_authentication?
        sign_up(resource_name, resource)
        redirect_to after_sign_up_path_for(resource)
      else
        expire_data_after_sign_in!
        redirect_to new_user_session_path, notice: "You have signed up successfully."
      end
    else
      clean_up_passwords resource
      redirect_to new_user_registration_path, inertia: { errors: resource.errors.to_hash(true) }
    end
  end
end
