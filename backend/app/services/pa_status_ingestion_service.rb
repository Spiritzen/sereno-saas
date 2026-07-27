# frozen_string_literal: true

# LE COULOIR UNIQUE d'ingestion des statuts entrants de la PA.
#
# Aujourd'hui appelé par le bouton « Synchroniser maintenant » (contrôleur
# HTTP). Demain, le job de polling (B3.1b) et le webhook (B3.3) l'appelleront
# aussi. Aucune règle métier de l'ingestion ne doit exister ailleurs : ce
# service est écrit pour être invoqué par plusieurs portes d'entrée.
#
# SÉQUENCE EN DEUX PHASES (P5 — jamais d'appel réseau dans une transaction) :
#   PHASE 1 (hors transaction) : charger la transmission éligible, résoudre
#     l'adapter, compter les observations déjà enregistrées, appeler
#     adapter.fetch_status. RIEN n'est persisté ici.
#   PHASE 2 (transaction courte) : déduplication, mapping, jugement par
#     FactureStatusTransitionPolicy, création de l'EvenementEntrantPa, et
#     SI ET SEULEMENT SI `applied`, mise à jour de Facture.statut +
#     création de l'EvenementFacture — Facture et EvenementFacture dans la
#     MÊME transaction (jamais un statut sans son événement).
class PaStatusIngestionService
  Resultat = Struct.new(
    :resultat,
    :motif,
    :evenement_entrant_pa,
    :statut_facture_avant,
    :statut_facture_apres,
    :transmission,
    keyword_init: true
  ) do
    def applied?
      resultat == "applied"
    end
  end

  class NonEligibleError < StandardError
    attr_reader :details

    def initialize(message = "Synchronisation impossible", details: [])
      @details = Array(details)
      @details = [ message ] if @details.empty?

      super(message)
    end
  end

  # V1.2c — GÉNÉRALISATION AU DOCUMENT (facture OU avoir), SANS RIEN CASSER :
  # `facture:` reste accepté tel quel (tous les appelants existants — bouton
  # manuel, job de polling, specs B3.3 — continuent de fonctionner sans
  # aucune modification), `document:` est le nouveau nom générique pour les
  # appelants qui manipulent déjà un avoir (webhook, polling généralisé).
  # Les deux se résolvent dans la même variable interne @document.
  def initialize(facture: nil, document: nil)
    @document = document || facture
    @organisation = @document.organisation
  end

  # MODE PULL (bouton manuel B3.1a, polling B3.1b) : retrouve la transmission
  # éligible, va chercher le statut auprès de la PA, puis délègue à #ingest.
  def call
    transmission = charger_transmission_eligible!

    # PHASE 1 — HORS TRANSACTION
    adapter = Pa::AdapterFactory.for(transmission.plateforme_agreee)
    observation_count = EvenementEntrantPa.where(transmission_pa: transmission).count
    status_result = adapter.fetch_status(transmission: transmission, observation_count: observation_count)

    ingest(transmission: transmission, status_result: status_result)
  end

  # MODE PUSH (webhook B3.3) : le Pa::StatusResult est déjà construit par
  # l'appelant depuis la notification reçue — AUCUN appel réseau ici. Point
  # d'entrée PUBLIC unique du couloir de persistance, partagé à l'identique
  # avec #call : même déduplication, même mapping, même
  # FactureStatusTransitionPolicy, même transaction, mêmes 5 résultats
  # possibles. Rien n'est dupliqué entre pull et push — seule la manière
  # d'obtenir le `status_result` diffère.
  def ingest(transmission:, status_result:)
    persister!(transmission, status_result)
  end

  private

  def charger_transmission_eligible!
    transmission = TransmissionPa
      .where(organisation: @organisation, statut: "depose")
      .where(document_association_attrs)
      .order(created_at: :desc)
      .first

    if transmission.blank?
      raise NonEligibleError.new(
        "Aucune transmission déposée à synchroniser pour ce document",
        details: [ "aucune transmission au statut \"depose\"" ]
      )
    end

    # ⚠️ DÉVIATION ARGUMENTÉE par rapport au §7 littéral du prompt B3.1a, qui
    # suggère d'exclure ici les factures dans un état terminal.
    #
    # Une telle garde rendrait la branche `requires_review` de
    # FactureStatusTransitionPolicy (§6 règle 5, "contradiction depuis un
    # état terminal") STRUCTURELLEMENT INATTEIGNABLE par ce service : dès
    # que la facture devient terminale, plus aucune synchronisation
    # manuelle ne pourrait jamais l'atteindre pour la classifier — alors que
    # §12 test 5 et le critère GREEN "une contradiction depuis un état
    # terminal -> requires_review, VISIBLE, non bloquant" exigent
    # explicitement que ce chemin soit exercé par le pipeline réel.
    #
    # L'ÉLIGIBILITÉ ne porte donc QUE sur la TRANSMISSION (dépôt acquis).
    # C'est au JUGE (la policy), pas à l'éligibilité, de dire si une
    # notification reçue alors que la facture est déjà terminale est une
    # simple confirmation sans changement (stale, règle 3) ou une
    # contradiction à signaler (requires_review, règle 5) — jamais un blocage
    # a priori de la synchronisation elle-même.
    #
    # Le "pause/stop automatique" évoqué au §0 comme hors périmètre B3.1a
    # concerne le futur JOB de polling (B3.1b), pas le bouton manuel : rien
    # n'empêche l'humain de cliquer "Synchroniser" sur une facture terminale
    # pour vérifier qu'aucune contradiction n'est apparue.
    transmission
  end

  def persister!(transmission, status_result)
    resultat = nil

    ActiveRecord::Base.transaction do
      @document.lock!

      cle = PaInboundDeduplicationKey.call(
        provider: status_result.provider,
        provider_event_id: status_result.provider_event_id,
        identifiant_pa: transmission.identifiant_pa,
        statut_brut: status_result.statut_brut,
        occurred_at: status_result.occurred_at,
        payload: status_result.raw_payload
      )

      existant = EvenementEntrantPa.find_by(cle_deduplication: cle)

      if existant.present?
        resultat = Resultat.new(
          resultat: "duplicate",
          motif: "Notification déjà enregistrée (même clé de déduplication)",
          evenement_entrant_pa: existant,
          statut_facture_avant: @document.statut,
          statut_facture_apres: @document.statut,
          transmission: transmission
        )

        raise ActiveRecord::Rollback
      end

      resultat = traiter_nouvelle_notification!(transmission, status_result, cle)
    end

    resultat
  end

  def traiter_nouvelle_notification!(transmission, status_result, cle)
    statut_candidat = PaStatusMapper.call(provider: status_result.provider, statut_brut: status_result.statut_brut)
    received_at = Time.current

    dernier_applique = EvenementEntrantPa
      .where(transmission_pa: transmission, resultat: "applied")
      .order(Arel.sql("COALESCE(occurred_at, received_at) DESC"))
      .first

    dernier_occurred_at_reference = dernier_applique && (dernier_applique.occurred_at || dernier_applique.received_at)
    occurred_at_effectif = status_result.occurred_at || received_at

    decision = FactureStatusTransitionPolicy.call(
      statut_facture_actuel: @document.statut,
      statut_candidat: statut_candidat,
      occurred_at: occurred_at_effectif,
      dernier_occurred_at_applique: dernier_occurred_at_reference
    )

    statut_avant = @document.statut

    evenement_entrant_pa = EvenementEntrantPa.create!(
      organisation: @organisation,
      transmission_pa: transmission,
      **document_association_attrs,
      provider: status_result.provider,
      provider_event_id: status_result.provider_event_id,
      cle_deduplication: cle,
      statut_brut: status_result.statut_brut,
      statut_candidat: statut_candidat,
      occurred_at: status_result.occurred_at,
      received_at: received_at,
      payload: status_result.raw_payload,
      resultat: decision.resultat,
      motif: decision.motif
    )

    if decision.applied?
      @document.update!(statut: statut_candidat)

      creer_evenement_statut!(statut_candidat, status_result, evenement_entrant_pa)
    end

    Resultat.new(
      resultat: decision.resultat,
      motif: decision.motif,
      evenement_entrant_pa: evenement_entrant_pa,
      statut_facture_avant: statut_avant,
      statut_facture_apres: @document.statut,
      transmission: transmission
    )
  end

  # V1.2c — un seul point qui sait vers quelle association affecter le
  # document (facture: ou avoir:), réutilisé pour la requête d'éligibilité
  # ET pour la création de l'EvenementEntrantPa : jamais de logique dupliquée.
  def document_association_attrs
    if @document.is_a?(Avoir)
      { avoir: @document }
    else
      { facture: @document }
    end
  end

  # V1.2c — le journal SUIT le document : evenement_avoir pour un avoir,
  # evenement_facture sinon (jamais l'inverse, jamais les deux). Mêmes
  # attributs, même "source" sandbox, que le couloir facture d'origine —
  # rien n'est dupliqué, seule la classe cible et l'association changent.
  def creer_evenement_statut!(statut_candidat, status_result, evenement_entrant_pa)
    attributs = {
      organisation: @organisation,
      statut: statut_candidat,
      source: "sandbox",
      code_statut_pa: status_result.statut_brut,
      payload: {
        simulation: true,
        provider: status_result.provider,
        statut_brut: status_result.statut_brut,
        occurred_at: status_result.occurred_at&.iso8601,
        pa_inbound_event_id: evenement_entrant_pa.id
      }
    }

    if @document.is_a?(Avoir)
      EvenementAvoir.create!(attributs.merge(avoir: @document))
    else
      EvenementFacture.create!(attributs.merge(facture: @document))
    end
  end
end
