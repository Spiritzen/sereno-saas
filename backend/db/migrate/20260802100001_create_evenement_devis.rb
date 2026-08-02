# frozen_string_literal: true

# Étage A devis→facture (V1.3) — journal append-only du devis.
#
# Miroir de CreateEvenementPaiement (20260731100002), pas de
# CreateEvenementFacture/Avoir : un devis n'a aucun canal externe (pas de PA,
# pas de webhook, jamais transmis) — comme un paiement, sa SEULE source
# possible est une action interne. `source` reste néanmoins présente (comme
# pour evenement_paiement) pour rester structurellement au même patron que
# les autres journaux, avec une liste fermée à une seule valeur.
#
# `expire` n'apparaît PAS dans la contrainte de statut : c'est un état DÉRIVÉ
# (Devis#expire?), jamais stocké, donc jamais journalisé par une transition.
class CreateEvenementDevis < ActiveRecord::Migration[8.1]
  def change
    create_table :evenement_devis, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid
      t.references :devis, null: false, foreign_key: true, type: :uuid
      t.references :utilisateur, null: true, foreign_key: true, type: :uuid

      t.string :statut, limit: 20, null: false
      t.string :source, limit: 20, null: false, default: "interne"
      t.jsonb :payload

      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :evenement_devis,
              [ :organisation_id, :devis_id ],
              name: "index_evenement_devis_on_org_and_devis"

    add_index :evenement_devis,
              [ :devis_id, :created_at ],
              name: "index_evenement_devis_on_devis_and_created_at"

    add_index :evenement_devis,
              [ :organisation_id, :created_at ],
              name: "index_evenement_devis_on_org_and_created_at"

    add_check_constraint :evenement_devis,
                         "statut IN ('brouillon', 'envoye', 'accepte', 'refuse')",
                         name: "check_evenement_devis_statut"

    add_check_constraint :evenement_devis,
                         "source IN ('interne')",
                         name: "check_evenement_devis_source"
  end
end
