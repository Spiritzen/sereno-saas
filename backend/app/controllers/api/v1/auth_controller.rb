# frozen_string_literal: true

require "digest"

class Api::V1::AuthController < Api::V1::BaseController
  # R2 (prompt_claude_code_inscription_owner_backend_r2.txt §1/§8) — les
  # primitives de cookies OWNER (poser_cookies_authentification et
  # consorts) sont PARTAGÉES via ce concern, pour permettre à
  # Api::V1::InscriptionsController d'émettre une session immédiatement
  # après inscription SANS dupliquer cette logique.
  # R2.1 (revue corrective, défaut d'architecture C) — #login appelle
  # désormais RÉELLEMENT emettre_session_owner! (la méthode de haut niveau
  # du concern, pas seulement ses primitives internes) : la séquence
  # complète « créer Session → encoder access token → poser cookies »
  # n'existe plus qu'à UN SEUL endroit (le concern), jamais dupliquée entre
  # #login et #create. #refresh reste volontairement séparé : il ne crée
  # jamais de nouvelle Session, il FAIT TOURNER (update!) le
  # refresh_token_hash d'une Session existante — opération métier distincte
  # d'emettre_session_owner!, qui ne partage que les primitives de bas
  # niveau (generer_refresh_token/hash_refresh_token/
  # poser_cookies_authentification), jamais la séquence complète.
  # Preuve de non-régression : auth_security_spec.rb reste intégralement
  # vert, sans aucune modification de ce fichier de spec.
  include SessionOwnerEmission

  skip_before_action :authenticate_request!, only: [ :login, :refresh ]

  rate_limit to: 5,
             within: 1.minute,
             only: :login,
             by: -> { "#{request.remote_ip}:#{params[:email].to_s.strip.downcase}" },
             with: -> { render json: { error: "Trop de tentatives, réessayez dans quelques instants" }, status: :too_many_requests }

  def login
    utilisateur = Utilisateur.includes(:organisation).find_by(
      email: login_params[:email].to_s.strip.downcase
    )

    unless utilisateur&.actif? && utilisateur.mot_de_passe_valide?(login_params[:password])
      return render json: { error: "Email ou mot de passe invalide" }, status: :unauthorized
    end

    emettre_session_owner!(utilisateur: utilisateur, organisation: utilisateur.organisation)

    render json: {
      message: "Connexion réussie",
      utilisateur: utilisateur_json(utilisateur),
      organisation: organisation_json(utilisateur.organisation)
    }, status: :ok
  end

  def refresh
    ancien_refresh_token = cookies[:refresh_token]

    return render_unauthorized("Refresh token manquant") if ancien_refresh_token.blank?

    ancien_refresh_token_hash = hash_refresh_token(ancien_refresh_token)

    session = Session.includes(:utilisateur, :organisation).find_by(
    refresh_token_hash: ancien_refresh_token_hash
    )

    return render_unauthorized("Session invalide") if session.blank?
    return render_unauthorized("Session expirée ou révoquée") unless session.active?

    utilisateur = session.utilisateur
    organisation = session.organisation

    return render_unauthorized("Utilisateur désactivé") unless utilisateur.actif?
    return render_unauthorized("Organisation invalide") unless utilisateur.organisation_id == organisation.id

    nouveau_refresh_token = generer_refresh_token

    session.with_lock do
    session.reload

    unless ActiveSupport::SecurityUtils.secure_compare(
      session.refresh_token_hash,
      ancien_refresh_token_hash
    )
      return render_unauthorized("Session invalide")
    end

  session.update!(
    refresh_token_hash: hash_refresh_token(nouveau_refresh_token),
    user_agent: request.user_agent,
    ip_adresse: request.remote_ip,
    expire_at: AuthTokenService::REFRESH_TOKEN_EXPIRATION.from_now
  )
end

    access_token = AuthTokenService.encode(
      utilisateur: utilisateur,
      organisation: organisation,
      session: session
    )

    poser_cookies_authentification(
      access_token: access_token,
      refresh_token: nouveau_refresh_token
    )

    render json: {
      message: "Session rafraîchie",
      utilisateur: utilisateur_json(utilisateur),
      organisation: organisation_json(organisation)
    }, status: :ok
  end

  def me
    render json: {
      utilisateur: utilisateur_json(Current.utilisateur),
      organisation: organisation_json(Current.organisation),
      session: {
        id: Current.session.id,
        expire_at: Current.session.expire_at
      }
    }, status: :ok
  end

  def logout
    Current.session.update!(revoque_at: Time.current)

    supprimer_cookies_authentification

    render json: { message: "Déconnexion réussie" }, status: :ok
  end

  private

  def login_params
    params.permit(:email, :password)
  end

  # emettre_session_owner! / generer_refresh_token / hash_refresh_token /
  # poser_cookies_authentification / supprimer_cookies_authentification /
  # cookie_secure? / cookie_same_site sont fournies par le concern
  # SessionOwnerEmission (inclus ci-dessus) — #login appelle désormais
  # emettre_session_owner! (cf. commentaire en tête de fichier) ; #refresh
  # continue d'utiliser uniquement les primitives de bas niveau, car il fait
  # tourner une Session EXISTANTE plutôt que d'en créer une nouvelle.

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
