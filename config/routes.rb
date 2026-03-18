require "sidekiq/web"

Rails.application.routes.draw do
  get "marketplace_accounts/index"
  get "marketplace_accounts/new"
  get "marketplace_accounts/create"
  get "orders/index"
  get "orders/show"
  get "inventory_adjustments/create"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  mount Sidekiq::Web => "/sidekiq"
  root "sessions#new"

  get "signup", to: "registrations#new"
  post "registrations", to: "registrations#create"

  get "login", to: "sessions#new"
  post "sessions", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  get "dashboard", to: "dashboard#index"
  resources :organizations, only: %i[new create]

  resources :organization_switches, only: [ :create ]

  resources :products do
    resources :variants, only: [ :create ]
    collection do
      post :bulk_push
    end
  end

  resources :variants, only: [ :update, :destroy ] do
    resources :listings, only: [ :create ]
  end

  resources :listings, only: [ :index, :update, :destroy, :edit ] do
    resources :repricing_rules, only: [ :new, :create, :update ]
  end

  resources :sync_events, only: [ :index ]

  resources :inventory_adjustments, only: [ :create ]

  resources :orders, only: [ :index, :show ]

  resources :marketplace_accounts, only: [ :index, :new, :create ]

  resources :sync, only: [ :index ] do
    collection do
      post :sync_orders
      post :sync_products
      post :sync_repricing
    end
  end

  namespace :webhooks do
    namespace :shopify do
      post :orders_create
      post :products_update
    end
  end
end
