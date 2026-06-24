class CreateNumerotations < ActiveRecord::Migration[8.1]
  def change
    create_table :numerotations, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid

      t.string :type_document, limit: 20, null: false
      t.integer :annee, null: false
      t.string :prefixe, limit: 20
      t.integer :dernier_numero, null: false, default: 0

      t.timestamps
    end

    add_index :numerotations,
              [:organisation_id, :type_document, :annee],
              unique: true,
              name: "index_numerotations_unique_sequence"

    add_check_constraint :numerotations,
                         "type_document IN ('facture', 'avoir', 'acompte', 'devis')",
                         name: "check_numerotations_type_document"

    add_check_constraint :numerotations,
                         "annee >= 2000",
                         name: "check_numerotations_annee"

    add_check_constraint :numerotations,
                         "dernier_numero >= 0",
                         name: "check_numerotations_dernier_numero_positive"
  end
end