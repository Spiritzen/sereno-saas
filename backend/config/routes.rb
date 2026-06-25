Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post "auth/login", to: "auth#login"
      get "auth/me", to: "auth#me"
      delete "auth/logout", to: "auth#logout"

      resources :clients do
        patch :archive, on: :member
        resources :contacts, only: [:index, :create]
      end

      resources :contacts, only: [:show, :update, :destroy]

      resources :factures do
  post :emettre, on: :member
  get :conformite, on: :member
  resources :lignes_facture, path: "lignes", only: [:index, :create]
end

      resources :lignes_facture, path: "lignes-facture", only: [:show, :update, :destroy]
    end
  end
end