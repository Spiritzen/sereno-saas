class CreateEvenementFacture < ActiveRecord::Migration[8.1]
  def change
    create_table :evenement_facture, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid
      t.references :facture, null: false, foreign_key: true, type: :uuid
      t.references :utilisateur, null: true, foreign_key: true, type: :uuid

      t.string :statut, limit: 30, null: false
      t.string :source, limit: 20, null: false, default: "interne"
      t.string :code_statut_pa, limit: 50
      t.jsonb :payload

      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :evenement_facture,
              [ :organisation_id, :facture_id ],
              name: "index_evenement_facture_on_org_and_facture"

    add_index :evenement_facture,
              [ :facture_id, :created_at ],
              name: "index_evenement_facture_on_facture_and_created_at"

    add_index :evenement_facture,
              [ :organisation_id, :created_at ],
              name: "index_evenement_facture_on_org_and_created_at"

    add_check_constraint :evenement_facture,
                         "statut IN ('brouillon', 'emise', 'deposee', 'recue', 'mise_a_disposition', 'approuvee', 'refusee', 'en_litige', 'encaissee', 'archivee', 'annulee')",
                         name: "check_evenement_facture_statut"

    add_check_constraint :evenement_facture,
                         "source IN ('interne', 'pa', 'webhook')",
                         name: "check_evenement_facture_source"
  end
end
