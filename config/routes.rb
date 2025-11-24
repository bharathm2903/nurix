Rails.application.routes.draw do
  # API routes for job management
  namespace :api do
    get 'metrics/index'
    # Job endpoints
    resources :jobs, only: [:create, :show, :index] do
      collection do
        get :status # GET /api/jobs/status/:id (alternative to show)
      end
    end
    
    # Metrics endpoint
    get 'metrics', to: 'metrics#index'
  end

  # Dashboard route
  root 'dashboard#index'
  get 'dashboard', to: 'dashboard#index'
  
  # ActionCable mount (if not already mounted)
  mount ActionCable.server => '/cable'

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
