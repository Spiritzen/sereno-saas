# frozen_string_literal: true

# JOB UNITAIRE : sonde UNE transmission. Enfilé par PaPollingScannerJob (le
# scanner planifie), jamais appelé directement par un contrôleur.
#
# ⚠️ COULOIR UNIQUE : ce job appelle PaStatusIngestionService — le MÊME
# service que le bouton « Vérifier maintenant » (B3.1a). Aucune règle de
# mapping/classification n'est recalculée ici. Ce job ne fait QUE de la
# PLANIFICATION : conditions d'arrêt, backoff, pause/stop.
class PaPollTransmissionJob < ApplicationJob
  queue_as :default

  DATE_LIMITE_TRANSMISSION = 90.days
  DATE_LIMITE_APRES_ECHEANCE = 30.days

  def perform(transmission_id)
    transmission = TransmissionPa.find_by(id: transmission_id)
    return if transmission.blank?

    # Garde AVANT tout appel : l'état a pu changer entre l'enfilage par le
    # scanner et l'exécution de ce job (ex. pause/stop déclenchés entre
    # temps, ou une synchro manuelle a déjà fait avancer la facture).
    return unless transmission.statut == "depose"
    return if transmission.polling_paused_at.present?
    return if transmission.polling_stopped_at.present?

    facture = transmission.facture
    return if facture.blank?

    return if stopper_si_condition_arret!(transmission, facture)

    begin
      resultat = PaStatusIngestionService.new(facture: facture).call
      traiter_resultat!(transmission, resultat)
    rescue Pa::NetworkError
      traiter_erreur_reseau!(transmission)
    end
  end

  private

  # ⚠️ RÈGLE N°1 (§1 du prompt B3.1b), et son ⚠️ ÉCART ARGUMENTÉ :
  #
  # Le prompt liste « facture dans un statut TERMINAL → STOP » comme
  # condition d'arrêt À VÉRIFIER AVANT TOUT APPEL (§7 point 2), au même titre
  # que l'expiration ou la plateforme désactivée. MAIS le prompt exige aussi,
  # de façon répétée et sans ambiguïté (§7 point 4, §12 test 8, §13 checklist)
  # que `requires_review` NE STOPPE NI NE PAUSE JAMAIS le polling. Or
  # `requires_review` ne peut être produit par FactureStatusTransitionPolicy
  # QUE lorsque le statut ACTUEL de la facture est déjà TERMINAL (règle 5 de
  # la policy, gelée, non modifiée). Une garde amont bloquant tout appel dès
  # que la facture est terminale rendrait donc `requires_review`
  # STRUCTURELLEMENT INATTEIGNABLE par ce job — exactement la même classe de
  # contradiction qu'en B3.1a (éligibilité vs requires_review), déjà réglée
  # dans le même sens : priorité à la branche de classification qui doit
  # rester atteignable et non bloquante.
  #
  # RÉSOLUTION RETENUE : aucune garde amont sur le statut terminal de la
  # facture. Le job appelle le service normalement. Le STOP pour
  # `facture_terminale` est déclenché UNIQUEMENT dans la branche `applied`
  # de #traiter_resultat! (voir plus bas), c'est-à-dire au moment précis où
  # CE job fait franchir à la facture un nouveau statut terminal — ce qui
  # couvre le cas réaliste (progression automatique jusqu'à `encaissee`) et
  # empêche bien tout sondage automatique ultérieur de cette transmission
  # (le scanner ne la sélectionnera plus jamais, polling_stopped_at posé).
  #
  # RESTE UNE LIMITE CONNUE (documentée dans le rapport) : si une facture
  # devient terminale par un autre chemin que ce job (ex. le bouton manuel
  # B3.1a) alors qu'une transmission reste activement planifiée, ce job
  # continuera à la sonder avec un backoff NORMAL (jamais plus resserré
  # qu'une observation sans changement, plafonné à 24h) jusqu'à ce que la
  # LIMITE TEMPORELLE (§8, ci-dessous) la stoppe pour de bon — borné, donc,
  # mais pas immédiat. Compromis assumé pour ne pas sacrifier
  # `requires_review`.
  def stopper_si_condition_arret!(transmission, facture)
    if date_limite(transmission, facture) <= Time.current
      stopper!(transmission, "polling_expired")
      return true
    end

    plateforme = transmission.plateforme_agreee

    if plateforme.blank? || plateforme.deconnectee?
      stopper!(transmission, "plateforme_desactivee")
      return true
    end

    false
  end

  def date_limite(transmission, facture)
    base_transmission = (transmission.transmis_at || transmission.created_at) + DATE_LIMITE_TRANSMISSION

    return base_transmission if facture.date_echeance.blank?

    base_echeance = facture.date_echeance.to_time + DATE_LIMITE_APRES_ECHEANCE

    [ base_transmission, base_echeance ].max
  end

  # STOP : aucun appel réseau, aucun événement — seulement les champs
  # techniques. `next_poll_at` remis à nil : plus rien à planifier.
  def stopper!(transmission, raison)
    transmission.update!(
      polling_stopped_at: Time.current,
      polling_stop_reason: raison,
      next_poll_at: nil
    )
  end

  def traiter_resultat!(transmission, resultat)
    if resultat.applied?
      if FactureStatusTransitionPolicy::TERMINAUX.include?(resultat.statut_facture_apres)
        transmission.update!(
          last_polled_at: Time.current,
          poll_attempts: transmission.poll_attempts + 1,
          consecutive_poll_errors: 0,
          poll_backoff_step: 0,
          polling_stopped_at: Time.current,
          polling_stop_reason: "facture_terminale",
          next_poll_at: nil
        )
      else
        transmission.update!(
          last_polled_at: Time.current,
          poll_attempts: transmission.poll_attempts + 1,
          consecutive_poll_errors: 0,
          poll_backoff_step: 0,
          next_poll_at: Time.current + PaPollingBackoff.normal_delay(0)
        )
      end

      return
    end

    # duplicate / stale / unmapped / requires_review : ⚠️ requires_review NE
    # BLOQUE PAS le polling (roadmap §4) — la facture reste utilisable, on
    # espace juste un cran de plus, comme n'importe quelle observation sans
    # changement.
    prochain_step = transmission.poll_backoff_step + 1

    transmission.update!(
      last_polled_at: Time.current,
      poll_attempts: transmission.poll_attempts + 1,
      consecutive_poll_errors: 0,
      poll_backoff_step: prochain_step,
      next_poll_at: Time.current + PaPollingBackoff.normal_delay(prochain_step)
    )
  end

  def traiter_erreur_reseau!(transmission)
    consecutive_errors = transmission.consecutive_poll_errors + 1

    if consecutive_errors >= PaPollingBackoff::MAX_CONSECUTIVE_ERRORS_BEFORE_PAUSE
      transmission.update!(
        last_polled_at: Time.current,
        poll_attempts: transmission.poll_attempts + 1,
        consecutive_poll_errors: consecutive_errors,
        polling_paused_at: Time.current,
        next_poll_at: nil
      )

      return
    end

    transmission.update!(
      last_polled_at: Time.current,
      poll_attempts: transmission.poll_attempts + 1,
      consecutive_poll_errors: consecutive_errors,
      next_poll_at: Time.current + PaPollingBackoff.error_delay(consecutive_errors - 1)
    )
  end
end
