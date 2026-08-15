class CreateDestinataireClientLinks < ActiveRecord::Migration[8.1]
  # Espace client — Étape A — SEULE table qui répond à « à qui appartient ce
  # client, et qui a le droit de le voir ». Une ligne = une preuve posée UNE
  # fois (jamais une correspondance automatique, cf. §1.4). `facture_id_preuve`
  # trace la facture dont le lien de portail a servi de preuve — traçabilité
  # RGPD/litige, jamais utilisée pour l'autorisation elle-même (celle-ci ne
  # dépend que de l'EXISTENCE de la ligne). Unique sur (compte_destinataire_id,
  # client_id) : un compte ne peut être lié qu'UNE fois à un même client.
  def change
    create_table :destinataire_client_links, id: :uuid do |t|
      # `comptes_destinataires` (pluriel français des deux mots) ne suit pas
      # l'inflexion anglaise par défaut de Rails pour :compte_destinataire
      # (qui devinerait "compte_destinataires") — même famille de cas que
      # `plateformes_agreees`/`PlateformeAgreee` déjà dans ce projet :
      # to_table explicite plutôt que renommer la table.
      t.references :compte_destinataire, null: false,
                    foreign_key: { to_table: :comptes_destinataires }, type: :uuid
      t.references :client, null: false, foreign_key: true, type: :uuid
      t.string :cree_via, null: false
      t.uuid :facture_id_preuve, null: false

      t.timestamps
    end

    add_foreign_key :destinataire_client_links, :factures, column: :facture_id_preuve

    add_index :destinataire_client_links,
              [ :compte_destinataire_id, :client_id ],
              unique: true,
              name: "index_destinataire_client_links_uniq"
  end
end
