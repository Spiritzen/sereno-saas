class Api::V1::BaseController < ApplicationController
  before_action :authenticate_request!
  after_action :reset_current

  private

  def authenticate_request!
    token = token_from_request

    return render_unauthorized("Token manquant") if token.blank?

    payload = AuthTokenService.decode(token)

    organisation = Organisation.find_by(id: payload[:organisation_id])
    utilisateur = Utilisateur.find_by(
      id: payload[:utilisateur_id],
      organisation_id: payload[:organisation_id]
    )
    session = Session.find_by(
      id: payload[:session_id],
      utilisateur_id: payload[:utilisateur_id],
      organisation_id: payload[:organisation_id]
    )

    return render_unauthorized("Organisation introuvable") if organisation.blank?
    return render_unauthorized("Utilisateur introuvable") if utilisateur.blank?
    return render_unauthorized("Utilisateur désactivé") unless utilisateur.actif?
    return render_unauthorized("Session invalide") if session.blank?
    return render_unauthorized("Session expirée ou révoquée") unless session.active?

    Current.organisation = organisation
    Current.utilisateur = utilisateur
    Current.session = session
  rescue AuthTokenService::ExpiredTokenError
    render_unauthorized("Token expiré")
  rescue AuthTokenService::DecodeError
    render_unauthorized("Token invalide")
  end

  def token_from_request
    cookies[:access_token].presence || bearer_token
  end

  def bearer_token
    authorization_header = request.headers["Authorization"]
    return nil if authorization_header.blank?

    authorization_header.split("Bearer ").last
  end

  def render_unauthorized(message)
    render json: { error: message }, status: :unauthorized
  end

  def reset_current
    Current.reset
  end
end