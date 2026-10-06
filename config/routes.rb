Rails.application.routes.draw do
  root "pages#home"
  %w[about services projects systems team contact].each { |p| get p, to: "pages##{p}" }
  resources :service_requests, only: :create

  get    "admin/login",  to: "sessions#new",     as: :admin_login
  post   "admin/login",  to: "sessions#create"
  delete "admin/logout", to: "sessions#destroy", as: :admin_logout

  get    "staff/login",  to: "staff_sessions#new",     as: :staff_login
  post   "staff/login",  to: "staff_sessions#create"
  delete "staff/logout", to: "staff_sessions#destroy", as: :staff_logout

  namespace :staff do
    root "tasks#index"
    resources :tasks, only: %i[index show update] do
      member do
        post :advance
        post :complete
      end
      resources :quotes, only: :create
    end
    resources :quotes, only: :show
    resources :maintenance_visits, only: %i[show update]
    resources :payments, only: %i[show update]
    resources :receipts, only: :show
  end

  namespace :admin do
    root "dashboard#index"
    resources :visits, only: :index
    resources :users, only: :index
    resources :service_requests, only: %i[index show update] do
      member { post :complete }
    end
    resources :maintenance_visits, only: %i[index create update destroy]
    resources :payments, only: %i[index show update]
    resources :receipts, only: :show
    resources :quotes, only: :show
    resources :installations, only: :update
    resources :solar_packages, except: :show
    resources :team_members
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
