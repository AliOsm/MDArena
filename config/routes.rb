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

  scope "/projects/:project_slug", as: :project, format: false, defaults: { format: :html } do
    get "files/*path/edit", to: "files#edit", as: :edit_file
    get "files/*path/download_md", to: "files#download_md", as: :download_md_file
    post "files/*path/download_pdf", to: "files#download_pdf", as: :download_pdf_file
    get "files/*path", to: "files#show", as: :file
    patch "files/*path", to: "files#update"
    delete "files/*path", to: "files#destroy", as: :destroy_file
  end

  namespace :settings do
    resources :tokens, only: [ :index, :create, :destroy ]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
