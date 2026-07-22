# frozen_string_literal: true

# V1.1-B3.1a — journal des notifications entrantes de la PA.
#
# Convention de nommage : suit le même pattern que les tables sœurs
# `evenement_facture` et `transmission_pa` (singulier, self.table_name
# explicite dans le modèle) plutôt que le pluriel français par défaut du
# reste du projet — cohérence avec les deux tables auxquelles ce modèle est
# directement lié.
#
# Append-only comme evenement_facture : uniquement created_at, pas
# d'updated_at (rien n'est jamais modifié après création).
class CreateEvenementEntrantPa < ActiveRecord::Migration[8.1]
  def change
    create_table :evenement_entrant_pa, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid
      t.references :transmission_pa, null: false, type: :uuid
      t.references :facture, null: false, foreign_key: true, type: :uuid

      t.string :provider, limit: 30, null: false
      t.string :provider_event_id, limit: 100
      t.string :cle_deduplication, null: false

      t.string :statut_brut, limit: 50, null: false
      t.string :statut_candidat, limit: 30

      t.datetime :occurred_at
      t.datetime :received_at, null: false

      t.jsonb :payload

      t.string :resultat, limit: 20, null: false
      t.text :motif

      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_foreign_key :evenement_entrant_pa, :transmission_pa, column: :transmission_pa_id

    add_index :evenement_entrant_pa, :cle_deduplication,
              unique: true,
              name: "index_evenement_entrant_pa_on_cle_deduplication"

    add_index :evenement_entrant_pa,
              [ :organisation_id, :facture_id ],
              name: "index_evenement_entrant_pa_on_org_and_facture"

    add_index :evenement_entrant_pa,
              [ :transmission_pa_id, :created_at ],
              name: "index_evenement_entrant_pa_on_transmission_and_created_at"

    add_index :evenement_entrant_pa, :resultat,
              name: "index_evenement_entrant_pa_on_resultat"

    add_check_constraint :evenement_entrant_pa,
                         "resultat IN ('applied', 'duplicate', 'stale', 'requires_review', 'unmapped')",
                         name: "check_evenement_entrant_pa_resultat"
  end
end
