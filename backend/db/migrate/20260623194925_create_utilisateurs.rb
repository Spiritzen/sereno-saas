class CreateUtilisateurs < ActiveRecord::Migration[8.1]
  def change
    create_table :utilisateurs, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid

      t.string :email, null: false
      t.string :mot_de_passe_hash, null: false
      t.string :nom, limit: 100, null: false
      t.string :prenom, limit: 100, null: false
      t.string :role, limit: 20, null: false, default: "membre"
      t.boolean :actif, null: false, default: true
      t.datetime :derniere_connexion_at

      t.timestamps
    end

    add_index :utilisateurs, :email, unique: true

    add_check_constraint :utilisateurs,
                         "role IN ('super_admin', 'owner', 'comptable', 'membre')",
                         name: "check_utilisateurs_role"
  end
end