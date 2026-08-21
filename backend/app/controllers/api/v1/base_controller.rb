class Api::V1::BaseController < ApplicationController
  include Pundit::Authorization

  before_action :authenticate_request!

  rescue_from Pundit::NotAuthorizedError, with: :render_forbidden
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  # R2.1 (revue corrective inscription OWNER, §6) — sans ce rescue_from, un
  # payload structurellement mal formé (racine `inscription` absente, ou
  # `params.require(...)` manquant plus généralement) fait remonter
  # ActionController::ParameterMissing NON intercepté. Sans handler dédié,
  # Rails le mappe bien en 400 par défaut, MAIS le CORPS de la réponse reste
  # la page HTML de debug interactive dès que `consider_all_requests_local`
  # est vrai (development ET test, cf. config/environments/*.rb) — un vrai
  # constat de la revue, vérifié empiriquement AVANT ce correctif (page
  # "Action Controller: Exception caught", backtrace complet). Placé ici
  # (BaseController, socle de TOUS les contrôleurs api/v1, y compris le
  # nouvel InscriptionsController PUBLIC) car c'est le lieu canonique déjà
  # utilisé par les deux rescue_from existants ci-dessus — jamais un nouveau
  # fichier, jamais une portée plus large que api/v1.
  rescue_from ActionController::ParameterMissing, with: :render_requete_invalide

  private

  def render_forbidden
  render json: { error: "Accès refusé" }, status: :forbidden
  end

  # Message STATIQUE, jamais exception.message (qui embarque le nom du
  # paramètre interne manquant, ex. "param is missing or the value is
  # empty: inscription") — aucune fuite de structure interne.
  def render_requete_invalide
    render json: { error: "Requête invalide" }, status: :bad_request
  end

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

  def pundit_user
  Current.utilisateur
  end

  def render_not_found
  render json: { error: "Ressource introuvable" }, status: :not_found
  end

  def render_validation_errors(record)
  render json: {
    error: "Validation échouée",
    details: record.errors.full_messages
  }, status: :unprocessable_entity
  end
end
