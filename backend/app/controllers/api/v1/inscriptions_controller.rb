# frozen_string_literal: true

module Api
  module V1
    # R2 (prompt_claude_code_inscription_owner_backend_r2.txt) — inscription
    # OWNER : crée atomiquement une Organisation et son premier Utilisateur
    # (role owner). Contrôleur MINCE — toute la logique transactionnelle vit
    # dans InscriptionOwnerService ; ce contrôleur se contente d'extraire des
    # strong params STRICTS, d'appeler le service, d'émettre une session en
    # réutilisant SessionOwnerEmission (stratégie A du §8 — même mécanique
    # que Api::V1::AuthController#login, jamais une deuxième implémentation
    # divergente des cookies OWNER), et de traduire les échecs attendus en
    # 422 sobre.
    #
    # PUBLIC PAR CONCEPTION (skip_before_action, même patron que
    # AuthController#login/#refresh) — TOUTES les autres routes api/v1
    # restent protégées exactement comme avant : aucun contournement global
    # de l'authentification.
    class InscriptionsController < Api::V1::BaseController
      include SessionOwnerEmission

      skip_before_action :authenticate_request!, only: [ :create ]

      # Même mécanisme NATIF Rails 8 que Api::V1::AuthController#login
      # (jamais Rack::Attack ici : le discriminateur IP+e-mail normalisé est
      # trivial à exprimer avec ce DSL, qui a déjà accès aux params parsés —
      # contrairement à un throttle Rack::Attack en middleware, qui ne peut
      # pas lire un corps JSON sans risquer de le consommer avant le
      # contrôleur). Seuil identique au login : 5/minute.
      # Retry-After explicite (§9.C) : le DSL rate_limit natif de Rails 8 ne
      # pose pas cet en-tête tout seul — posé ici à la largeur exacte de la
      # fenêtre (within), lisible par tout client HTTP standard.
      #
      # R2.1 (revue corrective, défaut bloquant B) — cette PREMIÈRE limite
      # (IP+e-mail) protège contre le brute-force d'UN compte/e-mail donné,
      # mais un appelant restant sur la MÊME IP et changeant d'e-mail à
      # chaque requête n'est jamais compté deux fois sur la même clé : il
      # peut alors tenter un nombre non borné d'inscriptions. D'où la
      # SECONDE limite ci-dessous (IP seule, tous e-mails confondus),
      # totalement INDÉPENDANTE (compteur/clé de cache distincts — deux
      # `name:` explicites, obligatoires dès qu'un contrôleur déclare
      # plusieurs `rate_limit`, cf. doc ActionController::RateLimiting).
      # Store : `cache_store` par défaut (config.cache_store), donc
      # Solid Cache en production — backend BASE DE DONNÉES, partagé par
      # TOUS les processus/instances de l'application (jamais local à un
      # seul processus) ; memory_store en dev/test (suffisant, mono-
      # processus). Vérifié en lisant config/environments/*.rb — aucune
      # protection illusoire.
      rate_limit to: 5,
                 within: 1.minute,
                 only: :create,
                 name: "owner-ip-email",
                 by: -> { "#{request.remote_ip}:#{email_owner_pour_rate_limit}" },
                 with: -> { render_rate_limited! }

      # Limite globale anti-spam : 20 tentatives/minute par IP, TOUS e-mails
      # confondus — ferme le contournement par rotation d'e-mail décrit
      # ci-dessus. Seuil délibérément plus large que 5 (ne doit jamais
      # gêner un usage normal derrière un NAT/proxy partagé), mais borne
      # strictement le volume d'inscriptions qu'une IP peut tenter.
      rate_limit to: 20,
                 within: 1.minute,
                 only: :create,
                 name: "owner-ip-global",
                 by: -> { request.remote_ip.to_s },
                 with: -> { render_rate_limited! }

      def create
        resultat = InscriptionOwnerService.call(
          organisation_attributes: organisation_params.to_h,
          utilisateur_attributes: utilisateur_params.to_h,
          mot_de_passe: params.dig(:inscription, :utilisateur, :mot_de_passe),
          confirmation_mot_de_passe: params.dig(:inscription, :utilisateur, :confirmation_mot_de_passe)
        )

        # Stratégie A (§8) : réutilisation directe de la mécanique OWNER
        # existante. Émise APRÈS la transaction (§6) : si cette étape
        # échouait de façon inattendue, l'Organisation et l'Utilisateur
        # DÉJÀ créés ne sont jamais annulés silencieusement — le compte
        # reste utilisable via /login. Portée volontairement étroite
        # (RecordInvalid uniquement) : jamais un rescue générique qui
        # masquerait un bug réel.
        #
        # R2.1 (revue corrective, §5) — le résultat de cette étape est
        # rendu EXPLICITE au frontend via `session_active`, plutôt que de
        # laisser le 201 sous-entendre une authentification qui n'a peut-
        # être pas eu lieu : le compte est déjà créé à ce stade, une
        # session ratée ne doit ni l'annuler ni donner l'illusion d'un
        # utilisateur connecté sur un futur appel à /auth/me.
        session_active = true
        begin
          emettre_session_owner!(utilisateur: resultat.utilisateur, organisation: resultat.organisation)
        rescue ActiveRecord::RecordInvalid => e
          session_active = false
          Rails.logger.warn(
            "[Api::V1::InscriptionsController] compte créé (utilisateur=#{resultat.utilisateur.id}) " \
            "mais émission de session impossible : #{e.message}"
          )
        end

        render json: {
          message: "Inscription réussie",
          utilisateur: utilisateur_json(resultat.utilisateur),
          organisation: organisation_json(resultat.organisation),
          session_active: session_active
        }, status: :created
      rescue InscriptionOwnerService::EchecInscription => e
        render json: { error: "Validation échouée", details: e.messages }, status: :unprocessable_entity
      end

      private

      # Aucun id, organisation_id ni role : ces champs sont explicitement
      # ABSENTS de la liste permise, même s'ils sont postés — ils n'existent
      # simplement jamais dans le hash transmis au service.
      def utilisateur_params
        params.require(:inscription).require(:utilisateur).permit(:prenom, :nom, :email)
      end

      # Aucun id : idem. fait_generateur_tva/numero_tva/forme_juridique/
      # telephone/iban/mentions_legales/identifiant_pa/logo_url sont
      # volontairement ABSENTS (décision produit §1 : différés à
      # l'onboarding, cf. rapport R2 §21/§22 du rapport de reconnaissance).
      def organisation_params
        params.require(:inscription).require(:organisation).permit(
          :raison_sociale, :siret, :regime_tva, :adresse_ligne1, :code_postal, :ville, :pays, :email
        )
      end

      def email_owner_pour_rate_limit
        params.dig(:inscription, :utilisateur, :email).to_s.strip.downcase
      end

      # Partagée par les DEUX rate_limit ci-dessus (IP+e-mail et IP-global) :
      # même réponse JSON sobre, même Retry-After — un appelant ne peut pas
      # distinguer laquelle des deux limites l'a arrêté.
      def render_rate_limited!
        response.set_header("Retry-After", 1.minute.to_i.to_s)
        render json: { error: "Trop de tentatives, réessayez dans quelques instants" }, status: :too_many_requests
      end

      # Même FORME de sérialisation que Api::V1::AuthController — dupliquée
      # ici à l'identique (2 méthodes, quelques lignes) plutôt que partagée :
      # l'extraction partagée est réservée à ce qui exigeait réellement une
      # réutilisation directe de mécanique existante (cookies, §1) ; un
      # simple gabarit JSON ne justifie pas d'élargir le périmètre du
      # concern ni de toucher AuthController une seconde fois.
      def utilisateur_json(utilisateur)
        {
          id: utilisateur.id,
          email: utilisateur.email,
          nom: utilisateur.nom,
          prenom: utilisateur.prenom,
          role: utilisateur.role,
          actif: utilisateur.actif
        }
      end

      def organisation_json(organisation)
        {
          id: organisation.id,
          raison_sociale: organisation.raison_sociale,
          siret: organisation.siret,
          regime_tva: organisation.regime_tva
        }
      end
    end
  end
end
