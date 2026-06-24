class CreatePlateformesAgreees < ActiveRecord::Migration[8.1]
  def change
    create_table :plateformes_agreees, id: :uuid do |t|
      t.references :organisation,
                   null: false,
                   foreign_key: true,
                   type: :uuid,
                   index: { unique: true }

      t.string :fournisseur, limit: 50, null: false
      t.string :type, limit: 20, null: false, default: "pa"
      t.string :api_url, null: false
      t.string :identifiant_compte
      t.text :credentials_chiffres
      t.string :statut, limit: 20, null: false, default: "connecte"
      t.datetime :connecte_at

      t.timestamps
    end

    add_check_constraint :plateformes_agreees,
                         "type IN ('pa', 'chorus_pro')",
                         name: "check_plateformes_agreees_type"

    add_check_constraint :plateformes_agreees,
                         "statut IN ('connecte', 'deconnecte', 'erreur')",
                         name: "check_plateformes_agreees_statut"
  end
end