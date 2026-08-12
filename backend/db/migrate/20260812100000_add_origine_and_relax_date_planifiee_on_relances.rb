class AddOrigineAndRelaxDatePlanifieeOnRelances < ActiveRecord::Migration[8.1]
  # Exécution du 12/08/2026 — sépare sans ambiguïté un acte MANUEL (v1a) d'un
  # futur acte PLANIFIÉ (v1b), pour que le planificateur ne les confonde
  # jamais. `date_planifiee` n'a de sens que pour une relance planifiée ; une
  # relance manuelle est un acte immédiat, sans date de planification.
  #
  # SÛRETÉ : la base de dev de Sébastien peut déjà contenir des relances
  # manuelles créées pendant ses tests. On procède donc en 3 temps pour ne
  # jamais échouer sur des lignes existantes :
  #   1) ajoute `origine` NULLABLE (jamais de NOT NULL direct sur une colonne
  #      neuve d'une table qui peut déjà avoir des lignes) ;
  #   2) backfille TOUTES les lignes existantes à "manuel" (seul le flux
  #      manuel existe à ce jour — cf. grep de RelanceService, aucun autre
  #      chemin de création) ;
  #   3) SEULEMENT ENSUITE bascule `origine` en NOT NULL, avec un défaut DB
  #      "manuel" en complément (aucune ligne ne peut donc se retrouver sans
  #      origine, y compris via un futur insert direct en base).
  def up
    add_column :relances, :origine, :string, limit: 20

    execute "UPDATE relances SET origine = 'manuel' WHERE origine IS NULL"

    change_column_default :relances, :origine, from: nil, to: "manuel"
    change_column_null :relances, :origine, false

    add_check_constraint :relances,
                          "origine IN ('manuel', 'planifie')",
                          name: "check_relances_origine"

    # `date_planifiee` n'est plus obligatoire dans TOUS les cas : une
    # relance manuelle (v1a) est un acte immédiat, elle n'a jamais de date de
    # planification. La présence conditionnelle (planifiee? uniquement) est
    # désormais portée par le modèle (validates ..., if: :planifiee?), pas
    # par la contrainte DB.
    change_column_null :relances, :date_planifiee, true
  end

  def down
    change_column_null :relances, :date_planifiee, false

    remove_check_constraint :relances, name: "check_relances_origine"
    change_column_null :relances, :origine, true
    change_column_default :relances, :origine, from: "manuel", to: nil
    remove_column :relances, :origine
  end
end
