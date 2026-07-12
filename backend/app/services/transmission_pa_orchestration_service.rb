# frozen_string_literal: true

# DIVERGENCE DE PATTERN ASSUMÉE ET DOCUMENTÉE :
# FactureEmissionService fait tout dans UNE seule transaction (aucun appel
# réseau à l'intérieur). Ce service N'EN FAIT PAS AUTANT, et c'est VOULU :
# Principe 5 — aucun appel réseau dans une transaction. La séquence est
# scindée en 3 phases : transaction courte (créer/retrouver la
# TransmissionPa en attente) -> appel adapter HORS transaction -> transaction
# courte (persister le résultat, éventuellement faire passer la Facture à
# `deposee` et créer l'EvenementFacture correspondant). Ce n'est pas une
# incohérence avec le pattern d'émission : l'émission ne fait aucun appel
# réseau, la transmission si.
#
# LIMITE CONNUE : si le process meurt entre la phase 1 et la phase 3, la
# transmission reste `en_attente` indéfiniment. Il n'existe pas encore de
# mécanisme de reprise automatique (prévu en V1.1-B3, job de polling). Le
# rejeu manuel reste sûr grâce à l'idempotency_key : la phase 1 réutilise la
# transmission `en_attente` existante avec sa même clé plutôt que d'en
# recréer une.
class TransmissionPaOrchestrationService
  class NonEligibleError < StandardError
    attr_reader :details

    def initialize(message = "Transmission impossible", details: [])
      @details = Array(details)
      @details = [ message ] if @details.empty?

      super(message)
    end
  end

  class TransmissionEchoueeError < StandardError
    attr_reader :transmission

    def initialize(message, transmission:)
      @transmission = transmission

      super(message)
    end
  end

  def initialize(facture:, utilisateur:)
    @facture = facture
    @utilisateur = utilisateur
    @organisation = facture.organisation
  end

  def call
    transmission = phase_1_preparer!

    if transmission.statut == "depose"
      @idempotent_hit = true
      return transmission
    end

    @idempotent_hit = false

    begin
      resultat = phase_2_appeler_adapter(transmission)
    rescue Pa::NetworkError, Pa::RejectedError => e
      phase_3_echec!(transmission, e)
    end

    phase_3_succes!(transmission, resultat)
  end

  # true si le résultat de #call est une transmission DÉJÀ déposée
  # (aucun appel adapter effectué lors de cet appel : idempotence pure).
  def idempotent_hit?
    @idempotent_hit
  end

  private

  def phase_1_preparer!
    ActiveRecord::Base.transaction do
      @facture.lock!

      plateforme = @organisation.plateforme_agreee

      if plateforme.blank?
        raise NonEligibleError.new(
          "Aucune plateforme agréée configurée pour cette organisation",
          details: [ "plateforme_agreee absente" ]
        )
      end

      # Une transmission active (en_attente ou déjà déposée) existante prime
      # sur le statut courant de la facture : c'est précisément le chemin de
      # l'idempotence (2e appel après dépôt) et de la reprise après crash
      # (2e appel alors que la 1re transmission est restée en_attente).
      # `emise?` n'est exigé que pour en CRÉER une nouvelle.
      transmission_active = TransmissionPa
        .where(organisation: @organisation, facture: @facture, plateforme_agreee: plateforme)
        .where.not(statut: "erreur")
        .order(created_at: :desc)
        .first

      if transmission_active.present?
        transmission_active
      else
        unless @facture.emise?
          raise NonEligibleError.new(
            "La facture doit être émise pour être transmise",
            details: [ "statut actuel : #{@facture.statut}" ]
          )
        end

        TransmissionPa.create!(
          organisation: @organisation,
          facture: @facture,
          plateforme_agreee: plateforme,
          direction: "sortant",
          format: @facture.format,
          statut: "en_attente",
          tentative: 1,
          idempotency_key: SecureRandom.uuid
        )
      end
    end
  end

  def phase_2_appeler_adapter(transmission)
    adapter = Pa::AdapterFactory.for(transmission.plateforme_agreee)
    adapter.submit(facture: @facture, transmission: transmission)
  end

  def phase_3_succes!(transmission, resultat)
    ActiveRecord::Base.transaction do
      transmission.update!(
        statut: resultat.normalized_status,
        identifiant_pa: resultat.external_id,
        accuse_reception: resultat.raw_payload,
        transmis_at: resultat.received_at
      )

      @facture.update!(statut: "deposee")

      EvenementFacture.create!(
        organisation_id: @organisation.id,
        facture_id: @facture.id,
        utilisateur_id: @utilisateur&.id,
        statut: "deposee",
        source: "sandbox",
        code_statut_pa: resultat.provider_status,
        payload: {
          simulation: true,
          provider: resultat.provider,
          external_id: resultat.external_id,
          provider_status: resultat.provider_status
        }
      )
    end

    transmission
  end

  def phase_3_echec!(transmission, error)
    ActiveRecord::Base.transaction do
      transmission.update!(
        statut: "erreur",
        message_erreur: error.message,
        tentative: transmission.tentative + 1
      )
    end

    raise TransmissionEchoueeError.new(error.message, transmission: transmission)
  end
end
