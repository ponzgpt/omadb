Rails.application.routes.draw do
  get "healthz" => "rails/health#show", as: :rails_health_check
  get "report" => "reporter#show", as: :reporter
  resources :reports, only: :create
  resources :machines, only: :show
  root "home#show"
end
