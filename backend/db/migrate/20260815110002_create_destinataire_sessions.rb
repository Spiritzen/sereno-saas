class CreateDestinataireSessions < ActiveRecord::Migration[8.1]
  # Espace client — Étape A — miroir exact de `sessions` (refresh_token_hash) :
  # même patron déjà éprouvé (SecureRandom + SHA256 + secure_compare +
  # expire_at/revoque_at), copié pour rester une pile TOTALEMENT séparée de
  # l'auth app (§1.1 execution_espace_client_etape_a) — jamais une réutilisation
  # du modèle Session lui-même.
  def change
    create_table :destinataire_sessions, id: :uuid do |t|
      # cf. commentaire équivalent dans create_destinataire_client_links.rb —
      # to_table explicite (comptes_destinataires n'est pas l'inflexion
      # Rails par défaut de :compte_destinataire).
      t.references :compte_destinataire, null: false,
                    foreign_key: { to_table: :comptes_destinataires }, type: :uuid
      t.string :token_hash, null: false
      t.datetime :expire_at, null: false
      t.datetime :revoque_at

      t.timestamps
    end

    add_index :destinataire_sessions, :token_hash, unique: true
  end
end
