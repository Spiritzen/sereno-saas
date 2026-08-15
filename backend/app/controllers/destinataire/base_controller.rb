# frozen_string_literal: true

module Destinataire
  # Base de la pile d'auth PARALLÈLE (§1.1 execution_espace_client_etape_a.txt) :
  # hérite directement d'ApplicationController, JAMAIS de Api::V1::BaseController.
  # Aucun Current.organisation n'est jamais posé sur ce chemin (§1.2) — pose
  # UNIQUEMENT Current.compte_destinataire / Current.destinataire_session.
  #
  # Erreurs 401 GÉNÉRIQUES (§4) : un seul message pour toute défaillance
  # d'authentification autre que « pas de token du tout » — jamais de detail
  # qui permettrait de distinguer compte inconnu / session révoquée / token
  # expiré (même discipline anti-énumération que Webhooks::PaController et
  # Portail::FacturesController).
  class BaseController < ApplicationController
    before_action :authenticate_destinataire!

    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

    private

    def authenticate_destinataire!
      token = token_from_request
      return render_unauthorized("Authentification requise") if token.blank?

      payload = DestinataireAuthTokenService.decode(token)

      compte = CompteDestinataire.find_by(id: payload[:compte_destinataire_id])
      session = DestinataireSession.find_by(
        id: payload[:session_id],
        compte_destinataire_id: payload[:compte_destinataire_id]
      )

      return render_unauthorized("Session invalide") if compte.blank? || session.blank?
      return render_unauthorized("Session invalide") unless session.actif?

      Current.compte_destinataire = compte
      Current.destinataire_session = session
    rescue DestinataireAuthTokenService::DecodeError
      # Couvre à la fois expiré ET invalide/mal typé — même message générique.
      render_unauthorized("Session invalide")
    end

    def token_from_request
      cookies[:destinataire_access_token].presence || bearer_token
    end

    def bearer_token
      authorization_header = request.headers["Authorization"]
      return nil if authorization_header.blank?

      authorization_header.split("Bearer ").last
    end

    def render_unauthorized(message)
      render json: { error: message }, status: :unauthorized
    end

    def render_not_found
      render json: { error: "Ressource introuvable" }, status: :not_found
    end

    protected

    # Partagé par Inscriptions#create et Sessions#create — ouvre une
    # DestinataireSession et pose les cookies. Mêmes réglages que
    # Api::V1::AuthController (mêmes ENV, même déploiement/domaine — pas de
    # raison d'avoir une politique de cookie différente), noms de cookie
    # DISTINCTS (jamais access_token/refresh_token, déjà pris par l'auth app).
    def emettre_session_destinataire!(compte)
      resultat = DestinataireSession.generer!(compte_destinataire: compte)
      access_token = DestinataireAuthTokenService.encode(compte_destinataire: compte, session: resultat.session)

      cookies[:destinataire_access_token] = {
        value: access_token,
        httponly: true,
        secure: cookie_secure?,
        same_site: cookie_same_site,
        expires: DestinataireAuthTokenService::ACCESS_TOKEN_EXPIRATION.from_now
      }

      cookies[:destinataire_refresh_token] = {
        value: resultat.brut,
        httponly: true,
        secure: cookie_secure?,
        same_site: cookie_same_site,
        expires: DestinataireSession::DUREE_VALIDITE.from_now
      }

      resultat.session
    end

    def supprimer_cookies_destinataire!
      [ :destinataire_access_token, :destinataire_refresh_token ].each do |nom_cookie|
        cookies.delete(nom_cookie, httponly: true, secure: cookie_secure?, same_site: cookie_same_site)
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
  end
end
