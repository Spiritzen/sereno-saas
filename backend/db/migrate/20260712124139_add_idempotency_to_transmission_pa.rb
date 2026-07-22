# frozen_string_literal: true

# Colonnes d'idempotence pour transmission_pa (V1.1-B1+B2).
#
# idempotency_key : NOT NULL sans backfill. Sûr car transmission_pa contient
# 0 ligne en local au moment de l'écriture de cette migration (confirmé par
# COUNT) — aucune donnée existante à migrer.
#
# Index unique global sur idempotency_key : une clé = une transmission,
# c'est le contrat d'idempotence lui-même.
#
# Index unique PARTIEL sur (organisation_id, facture_id, plateforme_agreee_id),
# limité aux transmissions non `erreur` : empêche un doublon de transmission
# active/réussie, tout en autorisant un nouvel essai (nouvelle ligne) après
# un échec technique.
class AddIdempotencyToTransmissionPa < ActiveRecord::Migration[8.1]
  def change
    add_column :transmission_pa, :idempotency_key, :uuid, null: false
    add_column :transmission_pa, :tentative, :integer, null: false, default: 0

    add_index :transmission_pa, :idempotency_key,
              unique: true,
              name: "index_transmission_pa_on_idempotency_key"

    add_index :transmission_pa,
              [ :organisation_id, :facture_id, :plateforme_agreee_id ],
              unique: true,
              where: "statut <> 'erreur'",
              name: "index_transmission_pa_on_org_facture_pa_active"
  end
end
