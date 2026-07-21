# frozen_string_literal: true

# V1.1-B3.1b — champs techniques de planification du polling sur
# `transmission_pa` (table SINGULIÈRE, cf. B3.1a).
#
# ⚠️ AJOUT AU-DELÀ DE LA LISTE LITTÉRALE DU PROMPT : `poll_backoff_step`.
# Le prompt ne prévoit que `consecutive_poll_errors` pour piloter le backoff
# D'ERREUR. Mais rien ne permet alors de retrouver, sans le stocker, où en
# est le backoff NORMAL (duplicate/stale/unmapped/requires_review) : le
# reconstruire en comparant next_poll_at à last_polled_at serait fragile dès
# que le jitter (±10%) entre en jeu (l'écart réel ne correspond plus
# exactement à une valeur de la table). `poll_backoff_step` stocke donc
# explicitement l'index courant dans PaPollingBackoff::NORMAL_STEPS —
# remis à 0 sur `applied`, avancé d'un cran sinon. Voir le rapport B3.1b.
#
# Backfill : AUCUN. `next_poll_at` reste NULL sur les lignes `depose`
# existantes ; le scanner les détecte via `next_poll_at IS NULL` (cf.
# PaPollingScannerJob) plutôt que via un UPDATE de données dans cette
# migration (qui resterait une modification de données, évitée ici).
class AddPollingFieldsToTransmissionPa < ActiveRecord::Migration[8.1]
  def change
    add_column :transmission_pa, :next_poll_at, :datetime
    add_column :transmission_pa, :last_polled_at, :datetime
    add_column :transmission_pa, :poll_attempts, :integer, null: false, default: 0
    add_column :transmission_pa, :consecutive_poll_errors, :integer, null: false, default: 0
    add_column :transmission_pa, :poll_backoff_step, :integer, null: false, default: 0
    add_column :transmission_pa, :polling_paused_at, :datetime
    add_column :transmission_pa, :polling_stopped_at, :datetime
    add_column :transmission_pa, :polling_stop_reason, :string, limit: 30

    add_index :transmission_pa, :next_poll_at, name: "index_transmission_pa_on_next_poll_at"

    add_index :transmission_pa, [ :statut, :next_poll_at ],
              name: "index_transmission_pa_on_statut_and_next_poll_at",
              where: "polling_paused_at IS NULL AND polling_stopped_at IS NULL"

    add_check_constraint :transmission_pa,
                         "polling_stop_reason IS NULL OR polling_stop_reason IN " \
                         "('facture_terminale', 'polling_expired', 'plateforme_desactivee', 'transmission_cloturee')",
                         name: "check_transmission_pa_polling_stop_reason"
  end
end
