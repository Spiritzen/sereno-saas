class CreateAbonnements < ActiveRecord::Migration[8.1]
  def change
    create_table :abonnements, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid

      t.string :plan, limit: 20, null: false, default: "gratuit"
      t.string :statut, limit: 20, null: false, default: "en_essai"
      t.date :date_debut, null: false
      t.date :date_fin
      t.decimal :prix_mensuel, precision: 8, scale: 2
      t.string :id_stripe, limit: 100

      t.timestamps
    end

    add_index :abonnements, :id_stripe

    add_check_constraint :abonnements,
                         "plan IN ('gratuit', 'pro')",
                         name: "check_abonnements_plan"

    add_check_constraint :abonnements,
                         "statut IN ('en_essai', 'actif', 'suspendu', 'annule')",
                         name: "check_abonnements_statut"

    add_check_constraint :abonnements,
                         "prix_mensuel IS NULL OR prix_mensuel >= 0",
                         name: "check_abonnements_prix_mensuel_positive"
  end
end
