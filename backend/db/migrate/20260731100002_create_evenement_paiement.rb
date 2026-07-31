class CreateEvenementPaiement < ActiveRecord::Migration[8.1]
  # Miroir exact de CreateEvenementAvoir (20260726103453) : table au nom
  # SINGULIER (convention des journaux du projet), id uuid, PAS de
  # updated_at (append-only, garanti au niveau modèle par EvenementPaiement).
  def change
    create_table :evenement_paiement, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid
      t.references :paiement, null: false, foreign_key: true, type: :uuid
      t.references :utilisateur, null: true, foreign_key: true, type: :uuid

      t.string :statut, limit: 20, null: false
      t.string :source, limit: 20, null: false, default: "interne"
      t.jsonb :payload

      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :evenement_paiement,
              [ :organisation_id, :paiement_id ],
              name: "index_evenement_paiement_on_org_and_paiement"

    add_index :evenement_paiement,
              [ :paiement_id, :created_at ],
              name: "index_evenement_paiement_on_paiement_and_created_at"

    add_index :evenement_paiement,
              [ :organisation_id, :created_at ],
              name: "index_evenement_paiement_on_org_and_created_at"

    add_check_constraint :evenement_paiement,
                         "statut IN ('brouillon', 'confirme', 'annule')",
                         name: "check_evenement_paiement_statut"

    add_check_constraint :evenement_paiement,
                         "source IN ('interne')",
                         name: "check_evenement_paiement_source"
  end
end
