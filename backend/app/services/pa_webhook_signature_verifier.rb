# frozen_string_literal: true

# R4 + R5 (B3.3) : preuve d'authenticité d'une notification webhook entrante.
#
# La signature couvre L'HORODATAGE ET LE CORPS BRUT ensemble
# ("timestamp.raw_body", à la Stripe) : signer le seul corps permettrait à un
# attaquant qui intercepte une requête valide de la REJOUER avec un nouveau
# timestamp de son choix sans invalider la signature. En liant les deux, tout
# changement de timestamp invalide la signature.
#
# ORDRE CRITIQUE (imposé par le prompt B3.3, §5 R4) : signature vérifiée
# AVANT la fenêtre temporelle. Comparaison à temps constant
# (ActiveSupport::SecurityUtils.secure_compare, jamais ==) — sinon la
# signature attendue fuit octet par octet via le temps de réponse.
#
# Fonction PURE : aucune lecture ni écriture DB, le secret est fourni par
# l'appelant (déjà résolu via PaInboundNotificationResolver +
# PlateformeAgreee#webhook_secret_chiffre). Ne connaît jamais l'organisation.
class PaWebhookSignatureVerifier
  ALGORITHME = "SHA256"
  FENETRE = 5.minutes

  MOTIFS = %i[
    secret_absent
    signature_absente
    timestamp_absent
    timestamp_invalide
    signature_invalide
    timestamp_hors_fenetre
  ].freeze

  Resultat = Struct.new(:valide, :motif, keyword_init: true) do
    def valide?
      valide
    end
  end

  def self.call(secret:, raw_body:, signature:, timestamp:)
    new(secret: secret, raw_body: raw_body, signature: signature, timestamp: timestamp).call
  end

  def initialize(secret:, raw_body:, signature:, timestamp:)
    @secret = secret
    @raw_body = raw_body.to_s
    @signature = signature
    @timestamp = timestamp
  end

  def call
    return rejet(:secret_absent) if @secret.blank?
    return rejet(:signature_absente) if @signature.blank?
    return rejet(:timestamp_absent) if @timestamp.blank?

    return rejet(:signature_invalide) unless signature_valide?

    instant = parser_timestamp(@timestamp)
    return rejet(:timestamp_invalide) if instant.blank?
    return rejet(:timestamp_hors_fenetre) if hors_fenetre?(instant)

    Resultat.new(valide: true, motif: nil)
  end

  private

  def signature_valide?
    attendue = OpenSSL::HMAC.hexdigest(ALGORITHME, @secret, message_signe)

    ActiveSupport::SecurityUtils.secure_compare(attendue, @signature.to_s)
  end

  def message_signe
    "#{@timestamp}.#{@raw_body}"
  end

  def parser_timestamp(brut)
    Time.iso8601(brut.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def hors_fenetre?(instant)
    (Time.current - instant).abs > FENETRE
  end

  def rejet(motif)
    Resultat.new(valide: false, motif: motif)
  end
end
