# frozen_string_literal: true

# Reprise TECHNIQUE d'un polling en PAUSE (V1.1-B3.2). Acte purement
# technique : ne rejoue AUCUN événement, ne crée AUCUN EvenementFacture ni
# EvenementEntrantPa, ne touche JAMAIS `statut` (ni facture ni transmission).
# Elle remet seulement la transmission dans la file de polling
# (next_poll_at) ; l'ingestion réelle repassera par le MÊME
# PaStatusIngestionService la prochaine fois que le job la sondera —
# couloir unique préservé, aucune règle d'ingestion dupliquée ici.
class PaPollingRelanceService
  class NonRelancableError < StandardError
    attr_reader :details

    def initialize(message = "Relance impossible", details: [])
      @details = Array(details)
      @details = [ message ] if @details.empty?

      super(message)
    end
  end

  def initialize(facture:)
    @facture = facture
    @organisation = facture.organisation
  end

  def call
    transmission = charger_transmission_deposee!

    ActiveRecord::Base.transaction do
      transmission.lock!

      verifier_eligibilite!(transmission)

      transmission.update!(
        polling_paused_at: nil,
        consecutive_poll_errors: 0,
        poll_backoff_step: 0,
        next_poll_at: Time.current + PaPollingBackoff.normal_delay(0)
      )
    end

    transmission
  end

  private

  def charger_transmission_deposee!
    transmission = TransmissionPa
      .where(organisation: @organisation, facture: @facture, statut: "depose")
      .order(created_at: :desc)
      .first

    if transmission.blank?
      raise NonRelancableError.new(
        "Aucune transmission déposée à relancer pour cette facture",
        details: [ "aucune transmission au statut \"depose\"" ]
      )
    end

    transmission
  end

  # Vérifiée APRÈS le lock (pas avant) : évite un TOCTOU entre la lecture
  # initiale et l'écriture si le job de polling touche la même ligne entre
  # temps (ex. il vient de la stopper définitivement pendant que l'humain
  # cliquait "Relancer").
  def verifier_eligibilite!(transmission)
    if transmission.polling_stopped_at.present?
      raise NonRelancableError.new(
        "Le polling de cette transmission est arrêté définitivement, pas en pause",
        details: [ "polling_stopped_at présent (raison : #{transmission.polling_stop_reason})" ]
      )
    end

    return if transmission.polling_paused_at.present?

    raise NonRelancableError.new(
      "Cette transmission n'est pas en pause, rien à relancer",
      details: [ "polling_paused_at absent" ]
    )
  end
end
