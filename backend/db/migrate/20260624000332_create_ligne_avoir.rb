class CreateLigneAvoir < ActiveRecord::Migration[8.1]
  def change
    create_table :ligne_avoir, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid
      t.references :avoir, null: false, type: :uuid, foreign_key: { to_table: :avoirs }

      t.string :designation, null: false
      t.decimal :quantite, precision: 10, scale: 2, null: false, default: 1
      t.decimal :prix_unitaire_ht, precision: 12, scale: 2, null: false
      t.decimal :taux_tva, precision: 5, scale: 2, null: false
      t.decimal :total_ht, precision: 12, scale: 2, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :ligne_avoir,
              [ :organisation_id, :avoir_id ],
              name: "index_ligne_avoir_on_org_and_avoir"

    add_index :ligne_avoir,
              [ :avoir_id, :position ],
              name: "index_ligne_avoir_on_avoir_and_position"

    add_check_constraint :ligne_avoir,
                         "quantite > 0",
                         name: "check_ligne_avoir_quantite_positive"

    add_check_constraint :ligne_avoir,
                         "prix_unitaire_ht >= 0",
                         name: "check_ligne_avoir_prix_unitaire_ht_positive"

    add_check_constraint :ligne_avoir,
                         "taux_tva >= 0",
                         name: "check_ligne_avoir_taux_tva_positive"

    add_check_constraint :ligne_avoir,
                         "total_ht >= 0",
                         name: "check_ligne_avoir_total_ht_positive"
  end
end
