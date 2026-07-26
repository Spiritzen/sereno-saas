class AddUniqueIndexToTransmissionPaIdentifiantPa < ActiveRecord::Migration[8.1]
  def change
    # R1 (B3.3) — identifiant_pa (external_id renvoyé par la PA au dépôt) est
    # le SEUL identifiant disponible pour rattacher une notification webhook
    # entrante à SA transmission, donc à SON organisation. Il est déjà unique
    # EN PRATIQUE pour le seul provider existant (sandbox : dérivé par
    # Digest::UUID.uuid_v5 d'un idempotency_key lui-même unique en base), mais
    # rien ne l'imposait jusqu'ici. On rend l'invariant EXPLICITE et vérifié
    # par la base plutôt qu'implicite et fragile — toute violation future
    # (nouvel adapter mal écrit) échouera bruyamment à l'écriture plutôt que
    # de permettre une résolution ambiguë cross-tenant au moment du webhook.
    #
    # Partiel (WHERE IS NOT NULL) : la colonne est NULL tant que la
    # transmission n'a pas encore été déposée avec succès (cf.
    # TransmissionPaOrchestrationService#phase_3_succes!) — plusieurs NULL
    # sont autorisés par un index unique Postgres, aucune contrainte à lever.
    add_index :transmission_pa,
              :identifiant_pa,
              unique: true,
              where: "identifiant_pa IS NOT NULL",
              name: "index_transmission_pa_on_identifiant_pa_unique"
  end
end
