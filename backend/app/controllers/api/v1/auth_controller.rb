# frozen_string_literal: true

require "digest"

class Api::V1::AuthController < Api::V1::BaseController
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

    refresh_token = generer_refresh_token

    session = utilisateur.sessions.create!(
      organisation: utilisateur.organisation,
      refresh_token_hash: hash_refresh_token(refresh_token),
      user_agent: request.user_agent,
      ip_adresse: request.remote_ip,
      expire_at: AuthTokenService::REFRESH_TOKEN_EXPIRATION.from_now
    )

    access_token = AuthTokenService.encode(
      utilisateur: utilisateur,
      organisation: utilisateur.organisation,
      session: session
    )

    poser_cookies_authentification(
      access_token: access_token,
      refresh_token: refresh_token
    )

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

  def generer_refresh_token
    SecureRandom.hex(64)
  end

  def hash_refresh_token(refresh_token)
    Digest::SHA256.hexdigest(refresh_token.to_s)
  end

  def poser_cookies_authentification(access_token:, refresh_token:)
    cookies[:access_token] = {
      value: access_token,
      httponly: true,
      secure: cookie_secure?,
      same_site: cookie_same_site,
      expires: AuthTokenService::ACCESS_TOKEN_EXPIRATION.from_now
    }

    cookies[:refresh_token] = {
      value: refresh_token,
      httponly: true,
      secure: cookie_secure?,
      same_site: cookie_same_site,
      expires: AuthTokenService::REFRESH_TOKEN_EXPIRATION.from_now
    }
  end

  def supprimer_cookies_authentification
    [ :access_token, :refresh_token ].each do |nom_cookie|
      cookies.delete(
        nom_cookie,
        httponly: true,
        secure: cookie_secure?,
        same_site: cookie_same_site
      )
    end
  end

  def cookie_secure?
    Rails.env.production? || ActiveModel::Type::Boolean.new.cast(ENV.fetch("AUTH_COOKIE_SECURE", false))
  end

  def cookie_same_site
    valeur = ENV.fetch("AUTH_COOKIE_SAME_SITE", Rails.env.production? ? "none" : "lax").downcase

    same_site = valeur.in?(%w[lax strict none]) ? valeur.to_sym : :lax

    return :lax if same_site == :none && !cookie_secure?

    same_site
  end

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
