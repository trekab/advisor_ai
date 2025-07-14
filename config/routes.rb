Rails.application.routes.draw do
  get "instructions/index"
  get "instructions/edit"
  get "instructions/update"
  get "instructions/destroy"
  get "sessions/index"
  get "sessions/google_callback"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  get '/auth/:provider/callback', to: 'sessions#google_callback'
  get '/auth/failure', to: 'sessions#failure'
  delete '/logout', to: 'sessions#logout', as: :logout
  
  # HubSpot OAuth routes
  get '/auth/hubspot', to: 'sessions#hubspot_auth'
  get '/auth/hubspot/callback', to: 'sessions#hubspot_callback'
  root 'sessions#index'
  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  resources :messages, only: [:index, :create]
  resources :instructions, only: [:index, :edit, :update, :destroy]
  resources :calendar, only: [:index] do
    collection do
      post :sync
    end
  end
  
  resources :dashboard, only: [:index] do
    collection do
      post :sync_now
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
