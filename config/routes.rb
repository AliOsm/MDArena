Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations"
  }
  devise_scope :user do
    delete "logout", to: "users/sessions#destroy", as: :logout
  end

  authenticate :user, ->(user) { user.admin? } do
    mount GoodJob::Engine, at: "good_job"
  end

  root "home#index"

  resources :projects, only: [ :index, :create ], param: :slug do
    member do
      get "/", action: :show
      get "settings", action: :settings
    end
    resources :files, only: [ :create ], param: :path
    resources :memberships, controller: "project_memberships", only: [ :create, :destroy ]
  end

  scope "/projects/:project_slug", as: :project, format: false, defaults: { format: :html } do
    get "files/*path/edit", to: "files#edit", as: :edit_file
    get "files/*path/history/:sha", to: "file_history#show", as: :file_history_show
    get "files/*path/history", to: "file_history#index", as: :file_history
get "files/*path", to: "files#show", as: :file
    patch "files/*path", to: "files#update"
    delete "files/*path", to: "files#destroy", as: :destroy_file
  end

  namespace :settings do
    resource :profile, only: [ :show, :update ], controller: "profile"
  end
  get "settings", to: redirect("/settings/profile")

  namespace :api do
    namespace :git do
      get "authorize", to: "authorize#show"
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
