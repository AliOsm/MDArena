Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations"
  }
  devise_scope :user do
    delete "logout", to: "users/sessions#destroy", as: :logout
  end

  root "home#index"

  resources :projects, only: [ :index, :create ], param: :slug do
    member do
      get "/", action: :show
    end
    resources :files, only: [ :create ], param: :path
  end

  namespace :settings do
    resources :tokens, only: [ :index, :create, :destroy ]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
