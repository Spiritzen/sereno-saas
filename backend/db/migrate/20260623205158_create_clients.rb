class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid

      t.string :type, limit: 20, null: false, default: "entreprise"
      t.string :raison_sociale, null: false
      t.string :siret, limit: 14
      t.string :numero_tva, limit: 20

      t.string :adresse_ligne1, null: false
      t.string :adresse_ligne2
      t.string :code_postal, limit: 10, null: false
      t.string :ville, limit: 100, null: false
      t.string :pays, limit: 2, null: false, default: "FR"

      t.string :email
      t.string :telephone, limit: 20
      t.string :identifiant_routage_pa, limit: 100
      t.string :statut, limit: 20, null: false, default: "actif"
      t.text :notes

      t.timestamps
    end

    add_index :clients, [ :organisation_id, :raison_sociale ]
    add_index :clients, [ :organisation_id, :siret ]
    add_index :clients, :identifiant_routage_pa

    add_check_constraint :clients,
                         "type IN ('entreprise', 'particulier', 'public')",
                         name: "check_clients_type"

    add_check_constraint :clients,
                         "statut IN ('actif', 'archive')",
                         name: "check_clients_statut"

    add_check_constraint :clients,
                         "siret IS NULL OR char_length(siret) = 14",
                         name: "check_clients_siret_length"

    add_check_constraint :clients,
                         "char_length(pays) = 2",
                         name: "check_clients_pays_length"
  end
end
