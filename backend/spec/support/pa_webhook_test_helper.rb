# frozen_string_literal: true

# Helper de test B3.3 (§6 du prompt) : forge un corps JSON + un horodatage +
# une signature HMAC valides pour Webhooks::PaController, sans tunnel/URL
# publique et sans jamais écrire de secret sur disque — chaque exemple génère
# le sien à la volée (SecureRandom), il ne vit qu'en mémoire et dans la base
# de test transactionnelle (rollback automatique fin d'exemple).
module PaWebhookTestHelper
  def webhook_secret
    SecureRandom.hex(32)
  end

  def webhook_timestamp(decalage: 0)
    (Time.current + decalage).utc.iso8601
  end

  def webhook_signature(secret:, raw_body:, timestamp:)
    OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{raw_body}")
  end

  # signature/timestamp explicitement surchargeables pour forger des cas
  # invalides (T-SIGNATURE-KO, T-REJEU-TEMPOREL) sans dupliquer la mécanique.
  # remote_addr (R6) : optionnel, uniquement pour isoler le throttle IP du
  # throttle organisation dans les tests de rate limiting — nil par défaut,
  # comportement des appels B3.3 existants strictement inchangé.
  def post_webhook_pa(raw_body:, secret:, timestamp: nil, signature: nil, remote_addr: nil)
    timestamp ||= webhook_timestamp
    signature ||= webhook_signature(secret: secret, raw_body: raw_body, timestamp: timestamp)

    post "/webhooks/pa",
         params: raw_body,
         headers: {
           "Content-Type" => "application/json",
           "X-Sereno-Signature" => signature,
           "X-Sereno-Signature-Timestamp" => timestamp
         },
         env: (remote_addr ? { "REMOTE_ADDR" => remote_addr } : nil)
  end
end

RSpec.configure do |config|
  config.include PaWebhookTestHelper, type: :request
end
