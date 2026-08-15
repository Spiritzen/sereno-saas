class CreateComptesDestinataires < ActiveRecord::Migration[8.1]
  # Espace client — Étape A (15/08/2026) — compte destinataire, AU-DESSUS des
  # organisations : contrairement à `utilisateurs.email` (unique GLOBALEMENT
  # mais TOUJOURS accompagné d'une organisation_id obligatoire), ce compte
  # n'appartient à AUCUNE organisation. `email` reste unique globalement
  # (identifiant de connexion), mais SANS AUCUN rapport avec `clients.email`
  # (non unique, non validé, jamais comparé — cf. §1.5 execution_espace_client_etape_a).
  def change
    create_table :comptes_destinataires, id: :uuid do |t|
      t.string :email, null: false
      t.string :mot_de_passe_hash, null: false

      t.timestamps
    end

    add_index :comptes_destinataires, :email, unique: true
  end
end
