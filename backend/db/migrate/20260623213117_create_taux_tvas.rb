class CreateTauxTvas < ActiveRecord::Migration[8.1]
  def change
    create_table :taux_tvas, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid

      t.string :libelle, limit: 50, null: false
      t.decimal :taux, precision: 5, scale: 2, null: false
      t.string :mention_exoneration
      t.boolean :par_defaut, null: false, default: false

      t.timestamps
    end

    add_index :taux_tvas, [:organisation_id, :libelle]
    add_index :taux_tvas,
              :organisation_id,
              unique: true,
              where: "par_defaut = true",
              name: "index_taux_tvas_unique_default_by_org"

    add_check_constraint :taux_tvas,
                         "taux >= 0",
                         name: "check_taux_tvas_taux_positive"
  end
end