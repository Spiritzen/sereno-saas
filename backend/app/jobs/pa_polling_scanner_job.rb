# frozen_string_literal: true

# SCANNER RÉCURRENT (config/recurring.yml, toutes les minutes). La BASE est
# la source de vérité — pas la file d'attente (§4 du prompt B3.1b) :
# `next_poll_at` est une mémoire durable, un simple SELECT dit qui attend
# d'être sondé, et un redémarrage/crash n'efface jamais rien. Auto-réparateur.
#
# Deux responsabilités distinctes, deux méthodes :
#   1. enfiler un PaPollTransmissionJob par transmission `depose` due
#   2. reprendre les transmissions bloquées en `en_attente` (dette B1+B2)
#
# CONCURRENCE : `SELECT ... FOR UPDATE SKIP LOCKED` sur la sélection, dans
# UNE transaction couvrant sélection + repousse de next_poll_at + enfilage.
# Deux scans concurrents se partagent alors les lignes (SKIP LOCKED) plutôt
# que de les traiter deux fois ; et un même scan ne peut pas être rejoué
# sur les mêmes lignes avant qu'elles n'aient été repoussées, puisque le
# repoussement fait partie de la même transaction que la sélection.
class PaPollingScannerJob < ApplicationJob
  queue_as :default

  # Borne le nombre de lignes traitées par passage — jamais toute la table
  # en mémoire (§6 du prompt).
  BATCH_SIZE = 200

  # Le temps qu'on laisse au worker pour traiter un PaPollTransmissionJob
  # avant qu'un nouveau passage du scanner ne puisse re-sélectionner la même
  # transmission (anti double-enfilage, cf. §6).
  REPOUSSE_IMMEDIATE = 1.minute

  # Une TransmissionPa reste `en_attente` seulement le temps d'un accusé PA
  # (quelques secondes en sandbox). Au-delà de ce seuil, elle est considérée
  # bloquée (process mort entre phase 1 et phase 3 de B1+B2).
  SEUIL_BLOCAGE = 30.minutes

  def perform
    sonder_transmissions_dues!
    reprendre_transmissions_bloquees!
  end

  private

  def sonder_transmissions_dues!
    ActiveRecord::Base.transaction do
      transmissions_dues.each do |transmission|
        transmission.update!(next_poll_at: Time.current + REPOUSSE_IMMEDIATE)
        PaPollTransmissionJob.perform_later(transmission.id)
      end
    end
  end

  # `next_poll_at IS NULL` capture aussi bien les transmissions `depose`
  # jamais encore amorcées (aucun backfill fait en migration, cf. §5) que
  # celles qui, par accident, n'auraient pas reçu de planification.
  def transmissions_dues
    TransmissionPa
      .where(statut: "depose", polling_paused_at: nil, polling_stopped_at: nil)
      .where("next_poll_at IS NULL OR next_poll_at <= ?", Time.current)
      .order(Arel.sql("next_poll_at ASC NULLS FIRST"))
      .limit(BATCH_SIZE)
      .lock("FOR UPDATE SKIP LOCKED")
  end

  # ⚠️ Reprendre une transmission bloquée = REJOUER LA SOUMISSION (chemin
  # TransmissionPaOrchestrationService), PAS un poll de statut entrant
  # (PaStatusIngestionService) : deux couloirs distincts, jamais mélangés.
  # Job séparé (PaRetryStuckSubmissionJob) plutôt que fusionné ici : deux
  # responsabilités différentes (planifier un poll / rejouer un dépôt), pas
  # de raison de les coupler dans un seul job.
  def reprendre_transmissions_bloquees!
    ActiveRecord::Base.transaction do
      transmissions_bloquees.each do |transmission|
        # Pas de champ de planification dédié pour l'anti double-enfilage
        # ici (hors périmètre §5) : le verrou FOR UPDATE SKIP LOCKED protège
        # deux scans strictement concurrents. Le rejeu lui-même reste sûr
        # (idempotency_key déterministe, B1+B2) si un très rare recoupement
        # entre deux passages successifs survenait malgré tout — limite
        # documentée dans le rapport B3.1b.
        PaRetryStuckSubmissionJob.perform_later(transmission.id)
      end
    end
  end

  def transmissions_bloquees
    TransmissionPa
      .where(statut: "en_attente")
      .where("created_at < ?", SEUIL_BLOCAGE.ago)
      .limit(BATCH_SIZE)
      .lock("FOR UPDATE SKIP LOCKED")
  end
end
