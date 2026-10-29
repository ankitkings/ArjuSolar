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
    get "parts", to: "parts#index"
    get "attendance", to: "attendance#show"
    post "attendance/check_in", to: "attendance#check_in", as: :attendance_check_in
    post "attendance/check_out", to: "attendance#check_out", as: :attendance_check_out
    resources :leave_requests, only: %i[index create] do
      member { patch :cancel }
    end
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
      resource :subsidy_documents, only: :update
    end
    resources :quotes, only: :show do
      member do
        post :whatsapp
        post :shared
        get :pdf
      end
    end
    resources :maintenance_visits, only: %i[show update]
    resources :payments, only: %i[show update] do
      member { get :upi_qr }
    end
    resources :receipts, only: :show
  end

  namespace :admin do
    root "dashboard#index"
    get "overdue", to: "overdue#index"
    patch "overdue/limits", to: "overdue#update_limits", as: :overdue_limits
    delete "overdue/limits", to: "overdue#reset_limits"
    get "my_tasks", to: "my_tasks#index"
    get "my_tasks/alert", to: "my_tasks#alert", as: :my_tasks_alert
    resource :margins, only: %i[show update], controller: "margins"
    get "attendance", to: "attendance#index"
    post "attendance", to: "attendance#mark"
    resources :leave_requests, only: :index do
      member do
        patch :approve
        patch :cancel
      end
    end
    get "payroll", to: "payroll#index"
    patch "payroll/settings", to: "payroll#settings", as: :payroll_settings
    get "payroll/:member_id", to: "payroll#show", as: :payroll_member
    patch "payroll/:member_id/salary", to: "payroll#salary", as: :payroll_salary
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
        post :release_installation
        post :release_payment
        patch :details
      end
    end
    resources :maintenance_visits, only: %i[index create update destroy]
    resources :payments, only: %i[index show update]
    resource :payment_settings, only: %i[show update], controller: "payment_settings"
    resources :receipts, only: :show
    resources :quotes, only: :show do
      member { get :pdf }
    end
    resources :installations, only: :update
    resources :solar_packages, except: :show
    resources :catalog_items, path: "parts", except: :show
    resource :stock, only: :show, controller: "stock" do
      post :receive
      post :order
      post "orders/:id/receive", action: :receive_order, as: :receive_order
      post "orders/:id/cancel", action: :cancel_order, as: :cancel_order
      post :adjust
      patch :min_level
      patch :rules
    end
    resource :subsidy, only: %i[show update], controller: "subsidy_schemes"
    resources :subsidy_applications, only: %i[index show create update]
    resources :team_members
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
