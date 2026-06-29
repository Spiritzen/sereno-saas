class CreateLigneDevis < ActiveRecord::Migration[8.1]
  def change
    create_table :ligne_devis, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid
      t.references :devis, null: false, type: :uuid, foreign_key: { to_table: :devis }
      t.references :produit, null: true, foreign_key: true, type: :uuid

      t.string :designation, null: false
      t.decimal :quantite, precision: 10, scale: 2, null: false, default: 1
      t.decimal :prix_unitaire_ht, precision: 12, scale: 2, null: false
      t.decimal :taux_tva, precision: 5, scale: 2, null: false
      t.decimal :total_ht, precision: 12, scale: 2, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :ligne_devis, [ :organisation_id, :devis_id ]
    add_index :ligne_devis, [ :devis_id, :position ]

    add_check_constraint :ligne_devis,
                         "quantite > 0",
                         name: "check_ligne_devis_quantite_positive"

    add_check_constraint :ligne_devis,
                         "prix_unitaire_ht >= 0",
                         name: "check_ligne_devis_prix_unitaire_ht_positive"

    add_check_constraint :ligne_devis,
                         "taux_tva >= 0",
                         name: "check_ligne_devis_taux_tva_positive"

    add_check_constraint :ligne_devis,
                         "total_ht >= 0",
                         name: "check_ligne_devis_total_ht_positive"
  end
end
