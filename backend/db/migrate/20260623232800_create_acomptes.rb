class CreateAcomptes < ActiveRecord::Migration[8.1]
  def change
    create_table :acomptes, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid
      t.references :client, null: false, foreign_key: true, type: :uuid
      t.references :facture, null: true, foreign_key: true, type: :uuid
      t.references :devis, null: true, type: :uuid, foreign_key: { to_table: :devis }

      t.string :numero, limit: 30
      t.decimal :pourcentage, precision: 5, scale: 2
      t.decimal :montant_ht, precision: 12, scale: 2, null: false
      t.decimal :montant_tva, precision: 12, scale: 2, null: false
      t.decimal :montant_ttc, precision: 12, scale: 2, null: false
      t.date :date_emission
      t.string :statut, limit: 20, null: false, default: "brouillon"

      t.timestamps
    end

    add_index :acomptes, [ :organisation_id, :client_id ]
    add_index :acomptes, [ :organisation_id, :facture_id ]
    add_index :acomptes, [ :organisation_id, :devis_id ]

    add_index :acomptes, [ :organisation_id, :numero ],
              unique: true,
              where: "numero IS NOT NULL",
              name: "index_acomptes_unique_numero_by_org"

    add_check_constraint :acomptes,
                         "statut IN ('brouillon', 'emis', 'encaisse', 'deduit')",
                         name: "check_acomptes_statut"

    add_check_constraint :acomptes,
                         "pourcentage IS NULL OR (pourcentage > 0 AND pourcentage <= 100)",
                         name: "check_acomptes_pourcentage_range"

    add_check_constraint :acomptes,
                         "montant_ht >= 0",
                         name: "check_acomptes_montant_ht_positive"

    add_check_constraint :acomptes,
                         "montant_tva >= 0",
                         name: "check_acomptes_montant_tva_positive"

    add_check_constraint :acomptes,
                         "montant_ttc >= 0",
                         name: "check_acomptes_montant_ttc_positive"
  end
end
