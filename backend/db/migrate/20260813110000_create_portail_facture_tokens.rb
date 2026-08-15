class CreatePortailFactureTokens < ActiveRecord::Migration[8.1]
  # Portail destinataire (MVP) — calqué sur `sessions` (refresh_token_hash) :
  # jamais le token BRUT en base, seulement son hash SHA256. `organisation_id`
  # dupliqué depuis facture.organisation_id (dénormalisé) pour scoper les
  # requêtes OWNER (générer/révoquer) par tenant sans jointure — le contrôleur
  # PUBLIC, lui, ne lit JAMAIS ce champ pour résoudre un token (cf. §1 :
  # résolution par token_hash uniquement, jamais par organisation/facture_id
  # fournis par l'appelant).
  def change
    create_table :portail_facture_tokens, id: :uuid do |t|
      t.references :facture, null: false, foreign_key: true, type: :uuid
      t.references :organisation, null: false, foreign_key: true, type: :uuid

      t.string :token_hash, null: false
      t.datetime :expire_at, null: false
      t.datetime :revoque_at

      t.timestamps
    end

    add_index :portail_facture_tokens, :token_hash, unique: true
    add_index :portail_facture_tokens,
              [ :facture_id, :revoque_at ],
              name: "index_portail_facture_tokens_on_facture_and_revoque_at"
  end
end
