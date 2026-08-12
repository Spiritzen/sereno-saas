class AddManualFieldsToRelances < ActiveRecord::Migration[8.1]
  # Additive uniquement : la table `relances` existe déjà (24/06/2026, jamais
  # câblée derrière un contrôleur/service — cf. rapport de reconnaissance
  # v1a). On complète sa forme pour porter l'acte réel d'une relance MANUELLE
  # (qui a cliqué, à quelle adresse, avec quel objet, par quel canal de
  # livraison RÉEL) sans toucher aux colonnes déjà posées (niveau,
  # date_planifiee, canal, statut, envoyee_at) : le futur planificateur (v1b)
  # les réutilisera telles quelles.
  def change
    add_reference :relances, :utilisateur, null: true, foreign_key: true, type: :uuid

    add_column :relances, :destinataire_email, :string
    add_column :relances, :objet, :string
    add_column :relances, :mode_livraison, :string, limit: 20
  end
end
