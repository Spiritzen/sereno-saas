Rails.application.routes.draw do
  # B3.3 — endpoint public (aucune auth JWT, régi par signature), hors du
  # namespace api/v1 authentifié : cf. Webhooks::PaController.
  namespace :webhooks do
    post "pa", to: "pa#recevoir"
  end

  # Portail destinataire (MVP) — endpoint PUBLIC (aucune auth JWT), régi par
  # la possession du token opaque, hors du namespace api/v1 authentifié :
  # cf. Portail::FacturesController, même montage que Webhooks::PaController.
  # ⚠️ L'URL ne porte QUE le token — jamais un id/facture_id (cf. §1
  # execution_portail_destinataire_mvp.txt).
  namespace :portail do
    get "factures/:token", to: "factures#show"
    get "factures/:token/pdf", to: "factures#pdf"
    get "factures/:token/avoirs", to: "factures#avoirs"
  end

  # Espace client — Étape A (15/08/2026) — pile d'auth PARALLÈLE à l'app,
  # hors du namespace api/v1 : cf. Destinataire::BaseController. AUCUNE
  # route ici n'accepte de client_id/organisation_id — le rattachement passe
  # UNIQUEMENT par un token de portail (§1 execution_espace_client_etape_a.txt).
  namespace :destinataire do
    post "inscription", to: "inscriptions#create"

    post "connexion", to: "sessions#create"
    delete "connexion", to: "sessions#destroy"

    get "moi", to: "moi#show"

    post "liens", to: "liens#create"

    delete "compte", to: "comptes#destroy"

    # Étape B (16/08/2026) — API lecture seule des factures du destinataire.
    # :id est TOUJOURS vérifié contre client_ids_revendiques dans le
    # contrôleur, jamais fait confiance tel quel (§1 execution_espace_client_etape_b.txt).
    get "factures", to: "factures#index"
    get "factures/:id", to: "factures#show"
    get "factures/:id/pdf", to: "factures#pdf"

    # execution_espace_client_sidebar_pagination_badge.txt §2 — sidebar
    # "Mes fournisseurs".
    get "fournisseurs", to: "fournisseurs#index"
  end

  namespace :api do
    namespace :v1 do
      post "auth/login", to: "auth#login"
      post "auth/refresh", to: "auth#refresh"
      get "auth/me", to: "auth#me"
      delete "auth/logout", to: "auth#logout"

      # R2 (prompt_claude_code_inscription_owner_backend_r2.txt) — inscription
      # OWNER (Organisation + premier Utilisateur, role owner). PUBLIQUE par
      # conception (cf. Api::V1::InscriptionsController), seule nouvelle
      # surface publique de ce sprint — toutes les autres routes api/v1
      # restent protégées exactement comme avant.
      post "inscription", to: "inscriptions#create"

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

  # Relances v1a — NICHÉES sous factures, même discipline que paiements
  # (décision Sébastien du 31/07/2026 reprise ici) : une relance n'a de sens
  # qu'attachée à une facture précise. Un seul verbe pour l'instant (bouton
  # manuel) — pas d'index/show/destroy : l'historique complet vit déjà sur
  # la facture (derniere_relance_at/relances_count, cf. FactureBlueprint).
  resources :relances, only: [ :create ]

  # Portail destinataire (MVP) — endpoints OWNER (générer/révoquer le lien
  # public). Le contrôleur PUBLIC qui sert la facture au tiers, lui, est
  # HORS api/v1 (cf. namespace :portail plus bas, même montage que
  # Webhooks::PaController).
  post "lien_portail", to: "portail_facture_tokens#create", on: :member
  delete "lien_portail", to: "portail_facture_tokens#destroy", on: :member
end

      # Organisation-scopée (pas liée à une facture précise) : badge B3.2.
      get "transmissions_pa/review_count", to: "transmissions_pa#review_count"

      # Export FEC (MVP) — organisation-scopée, pas liée à un document précis.
      # #fec_apercu (étiquette + nom de fichier, à afficher AVANT le
      # téléchargement) et #fec (le fichier .txt en pièce jointe).
      get "exports/fec", to: "exports#fec"
      get "exports/fec/apercu", to: "exports#fec_apercu"

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
