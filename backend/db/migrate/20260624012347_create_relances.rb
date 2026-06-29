class CreateRelances < ActiveRecord::Migration[8.1]
  def change
    create_table :relances, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid
      t.references :facture, null: false, foreign_key: true, type: :uuid

      t.integer :niveau, limit: 2, null: false, default: 1
      t.string :canal, limit: 20, null: false, default: "email"
      t.string :statut, limit: 20, null: false, default: "planifiee"
      t.date :date_planifiee, null: false
      t.datetime :envoyee_at

      t.timestamps
    end

    add_index :relances,
              [ :organisation_id, :facture_id ],
              name: "index_relances_on_org_and_facture"

    add_index :relances,
              [ :organisation_id, :statut ],
              name: "index_relances_on_org_and_statut"

    add_index :relances,
              [ :facture_id, :niveau ],
              name: "index_relances_on_facture_and_niveau"

    add_check_constraint :relances,
                         "niveau BETWEEN 1 AND 3",
                         name: "check_relances_niveau"

    add_check_constraint :relances,
                         "canal IN ('email', 'courrier')",
                         name: "check_relances_canal"

    add_check_constraint :relances,
                         "statut IN ('planifiee', 'envoyee', 'echec')",
                         name: "check_relances_statut"
  end
end
