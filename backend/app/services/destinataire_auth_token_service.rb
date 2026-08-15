# frozen_string_literal: true

# Espace client — Étape A — MIROIR d'AuthTokenService, copié pour rester une
# pile 100 % PARALLÈLE (§1.1 execution_espace_client_etape_a.txt) : jamais
# une réutilisation de la classe app, jamais un `organisation_id` dans le
# payload (§1.2).
#
# ⚠️ PAS DE CONFUSION DE TOKEN (§1.3) — DEUX garde-fous indépendants :
#   1) Claim `type: "destinataire"` dans le payload, vérifié à chaque décodage
#      ici — un token app n'a pas ce champ (`nil != "destinataire"`).
#   2) Clé de signature DÉRIVÉE de la clé app mais DISTINCTE (SHA256 d'un
#      préfixe + la clé app) — un token destinataire échoue la VÉRIFICATION
#      DE SIGNATURE JWT elle-même s'il est présenté à AuthTokenService.decode
#      (et réciproquement), pas seulement un contrôle de forme applicatif.
#      Aucune nouvelle credential à provisionner : dérivée localement,
#      jamais stockée, jamais un nouveau secret à gérer en prod.
class DestinataireAuthTokenService
  ALGORITHM = "HS256".freeze
  ACCESS_TOKEN_EXPIRATION = 30.minutes
  TYPE = "destinataire"

  class DecodeError < StandardError; end
  class ExpiredTokenError < DecodeError; end
  class TypeInvalideError < DecodeError; end

  def self.encode(compte_destinataire:, session:, expires_at: ACCESS_TOKEN_EXPIRATION.from_now)
    raise ArgumentError, "compte_destinataire obligatoire" if compte_destinataire.blank?
    raise ArgumentError, "session obligatoire" if session.blank?

    unless session.compte_destinataire_id == compte_destinataire.id
      raise ArgumentError, "la session ne correspond pas au compte"
    end

    payload = {
      type: TYPE,
      compte_destinataire_id: compte_destinataire.id,
      session_id: session.id,
      jti: SecureRandom.uuid,
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
    ).first.with_indifferent_access

    unless decoded_payload[:type] == TYPE
      raise TypeInvalideError, "Token n'est pas un token destinataire"
    end

    decoded_payload
  rescue JWT::ExpiredSignature
    raise ExpiredTokenError, "Token expiré"
  rescue JWT::DecodeError => e
    raise DecodeError, "Token invalide : #{e.message}"
  end

  def self.secret_key
    Digest::SHA256.hexdigest("destinataire:#{Rails.application.credentials.jwt_secret_key!}")
  end

  private_class_method :secret_key
end
