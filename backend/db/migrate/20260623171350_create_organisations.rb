class CreateOrganisations < ActiveRecord::Migration[8.1]
  def change
    create_table :organisations, id: :uuid do |t|
      t.string :raison_sociale, null: false
      t.string :forme_juridique, limit: 50
      t.string :siret, limit: 14, null: false
      t.string :numero_tva, limit: 20
      t.string :regime_tva, limit: 20, null: false, default: "franchise"

      t.string :adresse_ligne1, null: false
      t.string :adresse_ligne2
      t.string :code_postal, limit: 10, null: false
      t.string :ville, limit: 100, null: false
      t.string :pays, limit: 2, null: false, default: "FR"

      t.string :email, null: false
      t.string :telephone, limit: 20
      t.string :iban, limit: 34
      t.text :mentions_legales
      t.string :identifiant_pa, limit: 100
      t.string :logo_url, limit: 500

      t.timestamps
    end

    add_index :organisations, :siret, unique: true

    add_check_constraint :organisations,
                         "char_length(siret) = 14",
                         name: "check_organisations_siret_length"

    add_check_constraint :organisations,
                         "regime_tva IN ('franchise', 'reel_simplifie', 'reel_normal')",
                         name: "check_organisations_regime_tva"
  end
end
