Rails.application.routes.draw do
  devise_for :users
  devise_scope :user do
    delete "logout", to: "devise/sessions#destroy", as: :logout
  end

  root "home#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
