class CreatePaiements < ActiveRecord::Migration[8.1]
  def change
    create_table :paiements, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid
      t.references :facture, null: false, foreign_key: true, type: :uuid

      t.decimal :montant, precision: 12, scale: 2, null: false
      t.string :methode, limit: 20, null: false
      t.date :date_paiement, null: false
      t.string :reference, limit: 100

      t.timestamps
    end

    add_index :paiements,
              [:organisation_id, :facture_id],
              name: "index_paiements_on_org_and_facture"

    add_index :paiements,
              [:organisation_id, :date_paiement],
              name: "index_paiements_on_org_and_date"

    add_check_constraint :paiements,
                         "montant > 0",
                         name: "check_paiements_montant_positive"

    add_check_constraint :paiements,
                         "methode IN ('virement', 'carte', 'cheque', 'especes', 'prelevement')",
                         name: "check_paiements_methode"
  end
end