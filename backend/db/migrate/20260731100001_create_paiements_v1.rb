class CreatePaiementsV1 < ActiveRecord::Migration[8.1]
  # Table neuve, propre, qui remplace le squelette mort retiré par
  # 20260731100000_drop_paiements_mort.rb. Design append-only après
  # confirmation (statut brouillon/confirme/annule) — voir app/models/paiement.rb.
  #
  # methode_code : code UNTDID 4461 (pas un enum français à plat comme
  # l'ancien "methode") — réutilisable tel quel pour l'e-reporting futur.
  def change
    create_table :paiements, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid
      t.references :facture, null: false, foreign_key: true, type: :uuid

      t.decimal :montant, precision: 12, scale: 2, null: false
      t.string :methode_code, limit: 10, null: false
      t.date :date_encaissement, null: false
      t.string :reference, limit: 100
      t.string :statut, limit: 20, null: false, default: "brouillon"

      t.timestamps
    end

    add_index :paiements,
              [ :organisation_id, :facture_id ],
              name: "index_paiements_on_org_and_facture"

    add_index :paiements,
              [ :organisation_id, :date_encaissement ],
              name: "index_paiements_on_org_and_date"

    add_check_constraint :paiements,
                         "montant > 0",
                         name: "check_paiements_montant_positive"

    add_check_constraint :paiements,
                         "methode_code IN ('10', '20', '48', '58', '59')",
                         name: "check_paiements_methode_code"

    add_check_constraint :paiements,
                         "statut IN ('brouillon', 'confirme', 'annule')",
                         name: "check_paiements_statut"
  end
end
