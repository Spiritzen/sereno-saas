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

  # V1.2c — même discipline que PaStatusIngestionService : `facture:` reste
  # accepté tel quel pour ne rien casser côté appelants existants (contrôleur
  # facture, specs), `document:` est le nom générique pour les nouveaux
  # appelants (avoir). Les deux se résolvent dans @document.
  def initialize(facture: nil, document: nil, utilisateur:)
    @document = document || facture
    @utilisateur = utilisateur
    @organisation = @document.organisation
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
      @document.lock!

      plateforme = @organisation.plateforme_agreee

      if plateforme.blank?
        raise NonEligibleError.new(
          "Aucune plateforme agréée configurée pour cette organisation",
          details: [ "plateforme_agreee absente" ]
        )
      end

      # Une transmission active (en_attente ou déjà déposée) existante prime
      # sur le statut courant du document : c'est précisément le chemin de
      # l'idempotence (2e appel après dépôt) et de la reprise après crash
      # (2e appel alors que la 1re transmission est restée en_attente).
      # Le statut "emise" n'est exigé que pour en CRÉER une nouvelle.
      transmission_active = TransmissionPa
        .where(organisation: @organisation, plateforme_agreee: plateforme)
        .where(document_association_attrs)
        .where.not(statut: "erreur")
        .order(created_at: :desc)
        .first

      if transmission_active.present?
        transmission_active
      else
        # V1.2c : comparaison directe sur la CHAÎNE de statut, jamais sur un
        # nom de méthode prédicat — Facture#emise? et Avoir#emis? n'ont PAS
        # la même sémantique (emise? = strictement "emise" ; emis? = "pas
        # brouillon", donc aussi vrai pour deposee/recue/...). Utiliser
        # emis? par erreur ici autoriserait de créer une transmission pour
        # un avoir déjà déposé sans transmission active trouvée — un bug
        # silencieux. Le statut brut, lui, est une surface RÉELLEMENT commune.
        unless @document.statut == "emise"
          raise NonEligibleError.new(
            "Le document doit être émis pour être transmis",
            details: [ "statut actuel : #{@document.statut}" ]
          )
        end

        TransmissionPa.create!(
          organisation: @organisation,
          **document_association_attrs,
          plateforme_agreee: plateforme,
          direction: "sortant",
          format: format_document,
          statut: "en_attente",
          tentative: 1,
          idempotency_key: SecureRandom.uuid
        )
      end
    end
  end

  def phase_2_appeler_adapter(transmission)
    adapter = Pa::AdapterFactory.for(transmission.plateforme_agreee)
    adapter.submit(facture: @document, transmission: transmission)
  end

  def phase_3_succes!(transmission, resultat)
    ActiveRecord::Base.transaction do
      transmission.update!(
        statut: resultat.normalized_status,
        identifiant_pa: resultat.external_id,
        accuse_reception: resultat.raw_payload,
        transmis_at: resultat.received_at
      )

      @document.update!(statut: "deposee")

      creer_evenement_depot!(resultat)
    end

    transmission
  end

  # V1.2c — même document_association_attrs que PaStatusIngestionService
  # (dupliqué à l'identique plutôt que partagé : deux services distincts,
  # même style de duplication explicite que le reste du projet).
  def document_association_attrs
    if @document.is_a?(Avoir)
      { avoir: @document }
    else
      { facture: @document }
    end
  end

  # Avoir n'a pas de colonne format propre (toujours Factur-X aujourd'hui,
  # cf. AvoirXmlService) : on hérite du format de la facture corrigée plutôt
  # que d'inventer une valeur par défaut déconnectée de son origine.
  def format_document
    @document.respond_to?(:format) ? @document.format : @document.facture.format
  end

  def creer_evenement_depot!(resultat)
    attributs = {
      organisation_id: @organisation.id,
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
    }

    if @document.is_a?(Avoir)
      EvenementAvoir.create!(attributs.merge(avoir_id: @document.id))
    else
      EvenementFacture.create!(attributs.merge(facture_id: @document.id))
    end
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
