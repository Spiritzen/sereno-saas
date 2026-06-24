Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post "auth/login", to: "auth#login"
      get "auth/me", to: "auth#me"
      delete "auth/logout", to: "auth#logout"
    end
  end
end