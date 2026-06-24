class CreateLigneFacture < ActiveRecord::Migration[8.1]
  def change
    create_table :ligne_facture, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid
      t.references :facture, null: false, foreign_key: true, type: :uuid
      t.references :produit, null: true, foreign_key: true, type: :uuid

      t.string :designation, null: false
      t.decimal :quantite, precision: 10, scale: 2, null: false, default: 1
      t.decimal :prix_unitaire_ht, precision: 12, scale: 2, null: false
      t.decimal :taux_tva, precision: 5, scale: 2, null: false
      t.decimal :montant_tva, precision: 12, scale: 2, null: false
      t.decimal :total_ht, precision: 12, scale: 2, null: false
      t.decimal :total_ttc, precision: 12, scale: 2, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :ligne_facture,
              [:organisation_id, :facture_id],
              name: "index_ligne_facture_on_org_and_facture"

    add_index :ligne_facture,
              [:facture_id, :position],
              name: "index_ligne_facture_on_facture_and_position"

    add_check_constraint :ligne_facture,
                         "quantite > 0",
                         name: "check_ligne_facture_quantite_positive"

    add_check_constraint :ligne_facture,
                         "prix_unitaire_ht >= 0",
                         name: "check_ligne_facture_prix_unitaire_ht_positive"

    add_check_constraint :ligne_facture,
                         "taux_tva >= 0",
                         name: "check_ligne_facture_taux_tva_positive"

    add_check_constraint :ligne_facture,
                         "montant_tva >= 0",
                         name: "check_ligne_facture_montant_tva_positive"

    add_check_constraint :ligne_facture,
                         "total_ht >= 0",
                         name: "check_ligne_facture_total_ht_positive"

    add_check_constraint :ligne_facture,
                         "total_ttc >= 0",
                         name: "check_ligne_facture_total_ttc_positive"
  end
end