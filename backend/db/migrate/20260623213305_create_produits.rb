class CreateProduits < ActiveRecord::Migration[8.1]
  def change
    create_table :produits, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid
      t.references :taux_tva, null: true, foreign_key: true, type: :uuid

      t.string :designation, null: false
      t.text :description
      t.decimal :prix_unitaire_ht, precision: 12, scale: 2, null: false
      t.string :unite, limit: 20, default: "unité"
      t.boolean :actif, null: false, default: true

      t.timestamps
    end

    add_index :produits, [:organisation_id, :designation]

    add_check_constraint :produits,
                         "prix_unitaire_ht >= 0",
                         name: "check_produits_prix_unitaire_ht_positive"

    add_check_constraint :produits,
                         "unite IS NULL OR unite IN ('unité', 'heure', 'jour', 'forfait')",
                         name: "check_produits_unite"
  end
end