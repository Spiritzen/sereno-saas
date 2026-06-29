class CreateAvoirs < ActiveRecord::Migration[8.1]
  def change
    create_table :avoirs, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid
      t.references :facture, null: false, foreign_key: true, type: :uuid
      t.references :client, null: false, foreign_key: true, type: :uuid

      t.string :numero, limit: 30
      t.string :motif, null: false
      t.string :statut, limit: 30, null: false, default: "brouillon"

      t.date :date_emission

      t.decimal :total_ht, precision: 12, scale: 2, null: false, default: 0
      t.decimal :total_tva, precision: 12, scale: 2, null: false, default: 0
      t.decimal :total_ttc, precision: 12, scale: 2, null: false, default: 0

      t.string :pdf_url, limit: 500
      t.string :xml_url, limit: 500

      t.datetime :emis_at

      t.timestamps
    end

    add_index :avoirs, [ :organisation_id, :client_id ]
    add_index :avoirs, [ :organisation_id, :facture_id ]

    add_index :avoirs, [ :organisation_id, :numero ],
              unique: true,
              where: "numero IS NOT NULL",
              name: "index_avoirs_unique_numero_by_org"

    add_check_constraint :avoirs,
                         "statut IN ('brouillon', 'emise', 'deposee', 'recue', 'mise_a_disposition', 'approuvee', 'refusee', 'en_litige', 'encaissee', 'archivee', 'annulee')",
                         name: "check_avoirs_statut"

    add_check_constraint :avoirs,
                         "total_ht >= 0",
                         name: "check_avoirs_total_ht_positive"

    add_check_constraint :avoirs,
                         "total_tva >= 0",
                         name: "check_avoirs_total_tva_positive"

    add_check_constraint :avoirs,
                         "total_ttc >= 0",
                         name: "check_avoirs_total_ttc_positive"
  end
end
