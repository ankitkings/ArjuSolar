Rails.application.routes.draw do
  root "pages#home"
  %w[about services projects systems team contact].each { |p| get p, to: "pages##{p}" }
  resources :service_requests, only: :create
  get "q/:token/pdf", to: "public_quotes#pdf", as: :public_quote_pdf
  get "q/:token", to: "public_quotes#show", as: :public_quote   # the client's quotation page (opened from WhatsApp)

  get    "admin/login",  to: "sessions#new",     as: :admin_login
  post   "admin/login",  to: "sessions#create"
  delete "admin/logout", to: "sessions#destroy", as: :admin_logout

  get    "staff/login",  to: "staff_sessions#new",     as: :staff_login
  post   "staff/login",  to: "staff_sessions#create"
  delete "staff/logout", to: "staff_sessions#destroy", as: :staff_logout

  namespace :staff do
    root "tasks#index"
    resources :chats, only: %i[index show new create] do
      member do
        get :poll
        post :send_message
      end
      collection do
        post :direct
        get :unread
        get :notifications
      end
    end
    resources :tasks, only: %i[index show update] do
      member do
        post :advance
        post :complete
      end
      resources :quotes, only: %i[new create]
    end
    resources :quotes, only: :show do
      member do
        post :whatsapp
        post :shared
        get :pdf
      end
    end
    resources :maintenance_visits, only: %i[show update]
    resources :payments, only: %i[show update]
    resources :receipts, only: :show
  end

  namespace :admin do
    root "dashboard#index"
    resources :chats, only: %i[index show new create] do
      member do
        get :poll
        post :send_message
      end
      collection do
        post :direct
        get :unread
        get :notifications
      end
    end
    resources :visits, only: :index
    resources :users, only: %i[index edit update destroy]
    resources :service_requests, only: %i[index show update destroy] do
      member do
        post :complete
        get :edit_details
        patch :details
      end
    end
    resources :maintenance_visits, only: %i[index create update destroy]
    resources :payments, only: %i[index show update]
    resources :receipts, only: :show
    resources :quotes, only: :show do
      member { get :pdf }
    end
    resources :installations, only: :update
    resources :solar_packages, except: :show
    resources :catalog_items, path: "parts", except: :show
    resource :subsidy, only: %i[show update], controller: "subsidy_schemes"
    resources :subsidy_applications, only: %i[index show create update]
    resources :team_members
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
