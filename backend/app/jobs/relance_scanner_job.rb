# frozen_string_literal: true

# SCANNER RÉCURRENT (config/recurring.yml, tous les jours) — MIROIR de
# PaPollingScannerJob (patron du projet, cf. reco_relances_v1b_planificateur.txt
# R4) : la BASE est la source de vérité, ce job décide et enfile, il n'ENVOIE
# JAMAIS l'e-mail lui-même et ne fait AUCUNE I/O RÉSEAU dans la transaction.
#
# Architecture SCAN-AND-SEND (retenue, cf. execution_relances_v1b, en-tête) :
# rien n'est pré-créé à l'avance ("planifiee") — chaque passage recalcule
# l'éligibilité à la volée (relances.rb append-only ne permet de toute façon
# aucune transition d'état après coup).
#
# CONCURRENCE : `SELECT ... FOR UPDATE SKIP LOCKED` sur le pré-filtre SQL,
# dans UNE transaction. Contrairement à TransmissionPa (next_poll_at, un
# champ dédié que PaPollingScannerJob repousse pour empêcher un
# double-enfilage entre deux passages), aucun champ équivalent n'existe sur
# `factures` — le "dû maintenant" est entièrement DÉRIVÉ (relancable? +
# RelanceCadenceService) et rien ici ne change l'état de la Facture. Deux
# passages qui se chevauchent STRICTEMENT se partagent bien les lignes
# verrouillées (SKIP LOCKED empêche de les traiter deux fois DANS LA MÊME
# fenêtre), mais deux passages SUCCESSIFS (l'un après le commit de l'autre,
# avant que RelanceEnvoiJob n'ait eu le temps d'écrire la Relance) peuvent
# tous deux enfiler la même paire facture/niveau : c'est
# index_relances_auto_unique_par_niveau (§2 execution_relances_v1b) et la
# re-vérification dans RelanceEnvoiJob qui absorbent ce cas — jamais ce
# scanner.
class RelanceScannerJob < ApplicationJob
  queue_as :default

  # Borne le nombre de factures examinées par passage — jamais toute la
  # table en mémoire (même discipline que PaPollingScannerJob::BATCH_SIZE).
  BATCH_SIZE = 200

  def perform
    ActiveRecord::Base.transaction do
      factures_candidates.each do |facture|
        niveau = RelanceCadenceService.new(facture: facture).niveau_du
        next if niveau.nil?

        RelanceEnvoiJob.perform_later(facture.id, niveau)
      end
    end
  end

  private

  # Pré-filtre SQL volontairement LARGE (statut relançable + échéance
  # dépassée) : le reste à payer (dérivé, PaiementSyntheseService — somme de
  # paiements/avoirs, pas une colonne) et le palier/cooldown
  # (RelanceCadenceService) ne sont pas exprimables en SQL simple sans
  # dupliquer cette logique métier — ils sont vérifiés en Ruby juste après,
  # sur ce lot déjà verrouillé. `FOR UPDATE SKIP LOCKED` protège la
  # concurrence RÉELLE (deux scans qui se chevauchent ne verrouillent jamais
  # les mêmes lignes en même temps), au même titre que
  # PaPollingScannerJob#transmissions_dues.
  def factures_candidates
    Facture
      .where(statut: Relance::STATUTS_FACTURE_RELANCABLES)
      .where("date_echeance < ?", Date.current)
      .order(:date_echeance)
      .limit(BATCH_SIZE)
      .lock("FOR UPDATE SKIP LOCKED")
  end
end
