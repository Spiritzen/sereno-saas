class CreateEvenementAvoir < ActiveRecord::Migration[8.1]
  def change
    # Miroir exact de CreateEvenementFacture (20260624002221) : table au nom
    # SINGULIER (comme evenement_facture, evenement_entrant_pa — convention du
    # projet pour les journaux), id uuid, PAS de updated_at (append-only).
    create_table :evenement_avoir, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid
      t.references :avoir, null: false, foreign_key: true, type: :uuid
      t.references :utilisateur, null: true, foreign_key: true, type: :uuid

      t.string :statut, limit: 30, null: false
      t.string :source, limit: 20, null: false, default: "interne"
      t.string :code_statut_pa, limit: 50
      t.jsonb :payload

      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :evenement_avoir,
              [ :organisation_id, :avoir_id ],
              name: "index_evenement_avoir_on_org_and_avoir"

    add_index :evenement_avoir,
              [ :avoir_id, :created_at ],
              name: "index_evenement_avoir_on_avoir_and_created_at"

    add_index :evenement_avoir,
              [ :organisation_id, :created_at ],
              name: "index_evenement_avoir_on_org_and_created_at"

    add_check_constraint :evenement_avoir,
                         "statut IN ('brouillon', 'emise', 'deposee', 'recue', 'mise_a_disposition', 'approuvee', 'refusee', 'en_litige', 'encaissee', 'archivee', 'annulee')",
                         name: "check_evenement_avoir_statut"

    add_check_constraint :evenement_avoir,
                         "source IN ('interne', 'pa', 'webhook', 'sandbox')",
                         name: "check_evenement_avoir_source"
  end
end
