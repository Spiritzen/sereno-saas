class CreateDevis < ActiveRecord::Migration[8.1]
  def change
    create_table :devis, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid
      t.references :client, null: false, foreign_key: true, type: :uuid

      t.string :numero, limit: 30
      t.string :statut, limit: 20, null: false, default: "brouillon"
      t.string :objet
      t.date :date_emission
      t.date :date_validite

      t.decimal :total_ht, precision: 12, scale: 2, null: false, default: 0
      t.decimal :total_tva, precision: 12, scale: 2, null: false, default: 0
      t.decimal :total_ttc, precision: 12, scale: 2, null: false, default: 0

      t.text :conditions

      t.timestamps
    end

    add_index :devis, [ :organisation_id, :client_id ]
    add_index :devis, [ :organisation_id, :numero ], unique: true, where: "numero IS NOT NULL"

    add_check_constraint :devis,
                         "statut IN ('brouillon', 'envoye', 'accepte', 'refuse', 'expire')",
                         name: "check_devis_statut"

    add_check_constraint :devis,
                         "total_ht >= 0",
                         name: "check_devis_total_ht_positive"

    add_check_constraint :devis,
                         "total_tva >= 0",
                         name: "check_devis_total_tva_positive"

    add_check_constraint :devis,
                         "total_ttc >= 0",
                         name: "check_devis_total_ttc_positive"
  end
end
