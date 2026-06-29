class CreateEReporting < ActiveRecord::Migration[8.1]
  def change
    create_table :e_reporting, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid

      t.string :type, limit: 20, null: false
      t.date :periode_debut, null: false
      t.date :periode_fin, null: false
      t.string :statut, limit: 20, null: false, default: "en_attente"

      t.integer :nb_operations, null: false, default: 0
      t.decimal :montant_total, precision: 14, scale: 2, null: false, default: 0

      t.jsonb :payload
      t.datetime :transmis_at

      t.timestamps
    end

    add_index :e_reporting,
              [ :organisation_id, :type, :periode_debut, :periode_fin ],
              name: "index_e_reporting_on_org_type_and_period"

    add_index :e_reporting,
              [ :organisation_id, :statut ],
              name: "index_e_reporting_on_org_and_statut"

    add_check_constraint :e_reporting,
                         "type IN ('transactions', 'paiements')",
                         name: "check_e_reporting_type"

    add_check_constraint :e_reporting,
                         "statut IN ('en_attente', 'transmis', 'accepte', 'rejete')",
                         name: "check_e_reporting_statut"

    add_check_constraint :e_reporting,
                         "periode_fin >= periode_debut",
                         name: "check_e_reporting_periode_coherente"

    add_check_constraint :e_reporting,
                         "nb_operations >= 0",
                         name: "check_e_reporting_nb_operations_positive"

    add_check_constraint :e_reporting,
                         "montant_total >= 0",
                         name: "check_e_reporting_montant_total_positive"
  end
end
