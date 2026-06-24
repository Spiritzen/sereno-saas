class CreateFactures < ActiveRecord::Migration[8.1]
  def change
    create_table :factures, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid
      t.references :client, null: false, foreign_key: true, type: :uuid
      t.references :devis, null: true, type: :uuid, foreign_key: { to_table: :devis }

      t.string :numero, limit: 30
      t.string :type_document, limit: 20, null: false, default: "facture"
      t.string :statut, limit: 30, null: false, default: "brouillon"

      t.date :date_emission
      t.date :date_echeance

      t.decimal :total_ht, precision: 12, scale: 2, null: false, default: 0
      t.decimal :total_tva, precision: 12, scale: 2, null: false, default: 0
      t.decimal :total_ttc, precision: 12, scale: 2, null: false, default: 0
      t.decimal :montant_paye, precision: 12, scale: 2, null: false, default: 0

      t.string :devise, limit: 3, null: false, default: "EUR"
      t.string :format, limit: 20, null: false, default: "factur_x"

      t.text :mentions
      t.string :conditions_paiement
      t.string :pdf_url, limit: 500
      t.string :xml_url, limit: 500

      t.datetime :emise_at

      t.timestamps
    end

    add_index :factures, [:organisation_id, :client_id]
    # add_index :factures, :devis_id
    add_index :factures, [:organisation_id, :numero],
              unique: true,
              where: "numero IS NOT NULL",
              name: "index_factures_unique_numero_by_org"

    add_check_constraint :factures,
                         "type_document IN ('facture', 'acompte')",
                         name: "check_factures_type_document"

    add_check_constraint :factures,
                         "statut IN ('brouillon', 'emise', 'deposee', 'recue', 'mise_a_disposition', 'approuvee', 'refusee', 'en_litige', 'encaissee', 'archivee', 'annulee')",
                         name: "check_factures_statut"

    add_check_constraint :factures,
                         "total_ht >= 0",
                         name: "check_factures_total_ht_positive"

    add_check_constraint :factures,
                         "total_tva >= 0",
                         name: "check_factures_total_tva_positive"

    add_check_constraint :factures,
                         "total_ttc >= 0",
                         name: "check_factures_total_ttc_positive"

    add_check_constraint :factures,
                         "montant_paye >= 0",
                         name: "check_factures_montant_paye_positive"

    add_check_constraint :factures,
                         "char_length(devise) = 3",
                         name: "check_factures_devise_length"

    add_check_constraint :factures,
                         "format IN ('factur_x', 'ubl', 'cii')",
                         name: "check_factures_format"
  end
end