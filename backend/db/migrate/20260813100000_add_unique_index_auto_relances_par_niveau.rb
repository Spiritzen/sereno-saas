class AddUniqueIndexAutoRelancesParNiveau < ActiveRecord::Migration[8.1]
  # Filet d'idempotence DB pour le planificateur (v1b) : une relance AUTO
  # (origine "planifie") ne peut jamais être journalisée deux fois "envoyee"
  # au même niveau pour la même facture. Scope volontairement étroit :
  #   - origine "planifie" seulement : le MANUEL (origine "manuel") peut
  #     légitimement se répéter au niveau 1 (l'humain re-clique v1a) — un
  #     index sur (facture_id, niveau) tout court le casserait.
  #   - statut "envoyee" seulement : un rejeu après "echec" reste autorisé,
  #     l'index ne couvre pas les tentatives ratées.
  # RelanceCadenceService + RelanceEnvoiJob portent déjà la garde applicative
  # (§3/§5 de execution_relances_v1b_planificateur.txt) ; cet index est le
  # filet de dernier recours en cas de rejeu concurrent.
  def change
    add_index :relances,
              [ :facture_id, :niveau ],
              unique: true,
              where: "statut = 'envoyee' AND origine = 'planifie'",
              name: "index_relances_auto_unique_par_niveau"
  end
end
