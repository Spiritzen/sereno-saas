Rails.application.routes.draw do
  # B3.3 — endpoint public (aucune auth JWT, régi par signature), hors du
  # namespace api/v1 authentifié : cf. Webhooks::PaController.
  namespace :webhooks do
    post "pa", to: "pa#recevoir"
  end

  namespace :api do
    namespace :v1 do
      post "auth/login", to: "auth#login"
      post "auth/refresh", to: "auth#refresh"
      get "auth/me", to: "auth#me"
      delete "auth/logout", to: "auth#logout"

      resources :clients do
        patch :archive, on: :member
        resources :contacts, only: [ :index, :create ]
      end

      resources :contacts, only: [ :show, :update, :destroy ]

      # Devis→facture v1.3 étage B — routes À PLAT (décision Sébastien),
      # comme les avoirs : un devis a sa propre page de détail. Lignes
      # NICHÉES (comme lignes_avoir) : pas de route à plat séparée, le
      # frontend connaît déjà le devis_id.
      resources :devis do
        post :envoyer, on: :member
        post :accepter, on: :member
        post :refuser, on: :member
        post :convertir, on: :member

        resources :evenements_devis, path: "evenements", only: [ :index ]
        resources :lignes_devis, path: "lignes", only: [ :create, :update, :destroy ]
      end

resources :factures do
  post :emettre, on: :member
  get :conformite, on: :member
  get "pdf", to: "factures#pdf", on: :member

  member do
    get "factur-x/xml", to: "factures#factur_x_xml"
  end

  resources :lignes_facture, path: "lignes", only: [ :index, :create ]
  resources :evenements_facture, path: "evenements", only: [ :index ]
  resources :transmissions_pa, path: "transmissions", only: [ :index, :create ] do
    post :synchroniser, on: :collection
    post :relancer, on: :collection
  end

  # Paiements v1 étage B — NICHÉS sous factures (décision Sébastien, cf.
  # rapport de reconnaissance du 31/07/2026) : un paiement n'a de sens
  # qu'attaché à une facture précise. Pas de show/update/destroy (cf.
  # PaiementsController).
  resources :paiements, only: [ :index, :create ] do
    post :confirmer, on: :member
    post :annuler, on: :member

    resources :evenements_paiement, path: "evenements", only: [ :index ]
  end
end

      # Organisation-scopée (pas liée à une facture précise) : badge B3.2.
      get "transmissions_pa/review_count", to: "transmissions_pa#review_count"

      # V1.2b — index filtrable par ?facture_id= (comme factures#index avec
      # ?client_id=), pas de route nichée sous factures (décision Sébastien).
      resources :avoirs, only: [ :index, :show, :create ] do
        post :emettre, on: :member
        get :pdf, on: :member
        get :avoir_x_xml, on: :member

        resources :evenements_avoir, path: "evenements", only: [ :index ]

        # V1.2b-bis — miroir de lignes_facture, tout nichée (pas de route à
        # plat séparée : non nécessaire, le frontend connaît déjà l'avoir_id).
        resources :lignes_avoir, path: "lignes", only: [ :create, :update, :destroy ]

        # V1.2c — miroir des transmissions facture (pas de :relancer pour
        # l'instant, hors périmètre de ce sprint, cf. rapport).
        resources :transmissions_pa, path: "transmissions", only: [ :index, :create ],
                                      controller: "avoir_transmissions_pa" do
          post :synchroniser, on: :collection
        end
      end

      resources :lignes_facture, path: "lignes-facture", only: [ :show, :update, :destroy ]
    end
  end
end
