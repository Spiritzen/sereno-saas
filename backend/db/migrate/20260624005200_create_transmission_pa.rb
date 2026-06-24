class CreateTransmissionPa < ActiveRecord::Migration[8.1]
  def change
    create_table :transmission_pa, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid
      t.references :facture, null: true, foreign_key: true, type: :uuid
      t.references :avoir, null: true, type: :uuid, foreign_key: { to_table: :avoirs }
      t.references :plateforme_agreee,
             null: false,
             type: :uuid,
             foreign_key: { to_table: :plateformes_agreees }

      t.string :direction, limit: 10, null: false, default: "sortant"
      t.string :statut, limit: 30, null: false, default: "en_attente"
      t.string :format, limit: 20, null: false, default: "factur_x"

      t.string :identifiant_pa, limit: 100
      t.jsonb :accuse_reception
      t.text :message_erreur
      t.datetime :transmis_at

      t.timestamps
    end

    add_index :transmission_pa,
              [:organisation_id, :facture_id],
              name: "index_transmission_pa_on_org_and_facture"

    add_index :transmission_pa,
              [:organisation_id, :avoir_id],
              name: "index_transmission_pa_on_org_and_avoir"

    add_index :transmission_pa,
              [:organisation_id, :statut],
              name: "index_transmission_pa_on_org_and_statut"

    add_check_constraint :transmission_pa,
                         "direction IN ('sortant', 'entrant')",
                         name: "check_transmission_pa_direction"

    add_check_constraint :transmission_pa,
                         "statut IN ('en_attente', 'depose', 'accepte', 'rejete', 'erreur')",
                         name: "check_transmission_pa_statut"

    add_check_constraint :transmission_pa,
                         "format IN ('factur_x', 'ubl', 'cii')",
                         name: "check_transmission_pa_format"

    add_check_constraint :transmission_pa,
                         "((facture_id IS NOT NULL AND avoir_id IS NULL) OR (facture_id IS NULL AND avoir_id IS NOT NULL))",
                         name: "check_transmission_pa_one_document_target"
  end
end