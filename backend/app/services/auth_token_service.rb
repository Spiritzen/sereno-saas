class AuthTokenService
  ALGORITHM = "HS256".freeze
  ACCESS_TOKEN_EXPIRATION = 15.minutes

  class DecodeError < StandardError; end
  class ExpiredTokenError < DecodeError; end

  def self.encode(utilisateur:, organisation:, session:, expires_at: ACCESS_TOKEN_EXPIRATION.from_now)
    raise ArgumentError, "utilisateur obligatoire" if utilisateur.blank?
    raise ArgumentError, "organisation obligatoire" if organisation.blank?
    raise ArgumentError, "session obligatoire" if session.blank?

    unless utilisateur.organisation_id == organisation.id
      raise ArgumentError, "l'utilisateur n'appartient pas à cette organisation"
    end

    unless session.utilisateur_id == utilisateur.id && session.organisation_id == organisation.id
      raise ArgumentError, "la session ne correspond pas à l'utilisateur et à l'organisation"
    end

    payload = {
      utilisateur_id: utilisateur.id,
      organisation_id: organisation.id,
      session_id: session.id,
      iat: Time.current.to_i,
      exp: expires_at.to_i
    }

    JWT.encode(payload, secret_key, ALGORITHM)
  end

  def self.decode(token)
    decoded_payload = JWT.decode(
      token,
      secret_key,
      true,
      { algorithm: ALGORITHM }
    ).first

    decoded_payload.with_indifferent_access
  rescue JWT::ExpiredSignature
    raise ExpiredTokenError, "Token expiré"
  rescue JWT::DecodeError => e
    raise DecodeError, "Token invalide : #{e.message}"
  end

  def self.secret_key
    Rails.application.secret_key_base
  end

  private_class_method :secret_key
end