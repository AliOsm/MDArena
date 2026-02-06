Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations"
  }
  devise_scope :user do
    delete "logout", to: "users/sessions#destroy", as: :logout
  end

  root "home#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
