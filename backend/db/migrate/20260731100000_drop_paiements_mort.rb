class DropPaiementsMort < ActiveRecord::Migration[8.1]
  # Retire le squelette "paiement v0" (20260624011602_create_paiements.rb),
  # mort depuis la genèse du projet : jamais exposé par aucun controller/route,
  # 0 ligne en base, et dont le modèle mutait Facture directement (voir
  # rapportReconnaissancev1.txt du 31/07). Remplacé par une table neuve
  # (20260731100001_create_paiements.rb) au design append-only.
  #
  # ⚠️ La colonne factures.montant_paye N'EST PAS touchée ici : elle est lue
  # par le moteur GELÉ factur_x_xml_service.rb (BT-113/BT-115) et reste
  # intouchable. Seule la TABLE paiements (sans lien avec cette colonne) est
  # retirée.
  def change
    drop_table :paiements do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid
      t.references :facture, null: false, foreign_key: true, type: :uuid

      t.decimal :montant, precision: 12, scale: 2, null: false
      t.string :methode, limit: 20, null: false
      t.date :date_paiement, null: false
      t.string :reference, limit: 100

      t.timestamps
    end
  end
end
