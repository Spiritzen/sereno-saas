# frozen_string_literal: true

module Webhooks
  # R7 (B3.3) : endpoint PUBLIC, hérite directement d'ApplicationController
  # (PAS de Api::V1::BaseController -> pas de before_action authenticate_
  # request!, pas de JWT). Une PA n'a pas de compte Sereno : la seule preuve
  # d'authenticité acceptée ici est la signature (PaWebhookSignatureVerifier).
  #
  # ORDRE CRITIQUE, jamais réordonné : rattacher (R1) -> récupérer le secret
  # de CETTE organisation (R3) -> vérifier signature + fenêtre (R4+R5) ->
  # SEULEMENT ALORS ingérer via le couloir unique (R2). Aucune ingestion tant
  # que la notification n'est pas prouvée authentique et fraîche.
  #
  # AUCUNE fuite d'info dans les réponses d'erreur : rattachement introuvable
  # ET signature invalide rendent des messages génériques, jamais de détail
  # permettant à un appelant non authentifié de sonder l'existence d'un
  # identifiant ou d'une organisation.
  class PaController < ApplicationController
    SIGNATURE_HEADER = "X-Sereno-Signature"
    TIMESTAMP_HEADER = "X-Sereno-Signature-Timestamp"

    def recevoir
      raw_body = request.raw_post
      payload = parser_payload(raw_body)
      return render_erreur(:bad_request, "Corps de requête invalide") if payload.blank?

      identifiant_pa = payload["identifiant_pa"]
      statut_brut = payload["statut_brut"]
      return render_erreur(:bad_request, "Corps de requête invalide") if identifiant_pa.blank? || statut_brut.blank?

      # R1 — rattachement NON AMBIGU (identifiant_pa unique en base, cf.
      # migration dédiée). L'organisation et la facture sont des RÉSULTATS de
      # cette résolution, jamais une donnée présumée.
      resolution = PaInboundNotificationResolver.call(identifiant_pa: identifiant_pa)
      return render_erreur(:not_found, "Notification non rattachable") if resolution.blank?

      # R3 — secret PROPRE à l'organisation résolue, jamais un secret global.
      secret = resolution.plateforme_agreee&.webhook_secret_chiffre

      # R4 + R5 — preuve d'authenticité AVANT toute ingestion.
      verification = PaWebhookSignatureVerifier.call(
        secret: secret,
        raw_body: raw_body,
        signature: request.headers[SIGNATURE_HEADER],
        timestamp: request.headers[TIMESTAMP_HEADER]
      )
      return render_erreur(:unauthorized, "Signature invalide") unless verification.valide?

      # R2 — couloir unique : même StatusResult, même code de persistance que
      # le bouton manuel et le polling.
      status_result = construire_status_result(resolution.plateforme_agreee, payload)

      resultat = PaStatusIngestionService
        .new(facture: resolution.facture)
        .ingest(transmission: resolution.transmission, status_result: status_result)

      render json: { resultat: resultat.resultat }, status: :ok
    end

    private

    def parser_payload(raw_body)
      return nil if raw_body.blank?

      JSON.parse(raw_body)
    rescue JSON::ParserError
      nil
    end

    def construire_status_result(plateforme_agreee, payload)
      Pa::StatusResult.new(
        provider: plateforme_agreee.fournisseur,
        provider_event_id: payload["provider_event_id"],
        statut_brut: payload["statut_brut"],
        occurred_at: parser_occurred_at(payload["occurred_at"]),
        raw_payload: payload.slice("identifiant_pa", "statut_brut", "provider_event_id", "occurred_at")
      )
    end

    def parser_occurred_at(brut)
      return nil if brut.blank?

      Time.iso8601(brut)
    rescue ArgumentError, TypeError
      nil
    end

    def render_erreur(status, message)
      render json: { error: message }, status: status
    end
  end
end
