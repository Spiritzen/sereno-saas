# frozen_string_literal: true

# JOB SÉPARÉ de PaPollTransmissionJob à dessein : celui-ci REJOUE une
# soumission bloquée (couloir TransmissionPaOrchestrationService, B1+B2),
# l'autre SONDE un statut entrant (couloir PaStatusIngestionService, B3.1a).
# Deux responsabilités, deux services distincts — jamais mélangés.
#
# Sûr par construction : TransmissionPaOrchestrationService réutilise la
# transmission `en_attente` existante avec sa même idempotency_key plutôt
# que d'en recréer une ; l'adapter sandbox dérive un external_id
# déterministe à partir de cette clé. Rejouer ne peut donc pas produire de
# double dépôt.
class PaRetryStuckSubmissionJob < ApplicationJob
  queue_as :default

  def perform(transmission_id)
    transmission = TransmissionPa.find_by(id: transmission_id, statut: "en_attente")
    return if transmission.blank?

    facture = transmission.facture
    return if facture.blank?

    TransmissionPaOrchestrationService.new(facture: facture, utilisateur: nil).call
  rescue TransmissionPaOrchestrationService::NonEligibleError,
         TransmissionPaOrchestrationService::TransmissionEchoueeError
    # L'échec (technique ou d'éligibilité) est déjà persisté par le service
    # lui-même (la transmission passe en `erreur`, cf. B1+B2) : rien de plus
    # à faire ici. Reprise manuelle après pause = B3.2.
    nil
  end
end
