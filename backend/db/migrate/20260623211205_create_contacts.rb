class CreateContacts < ActiveRecord::Migration[8.1]
  def change
    create_table :contacts, id: :uuid do |t|
      t.references :organisation, null: false, foreign_key: true, type: :uuid
      t.references :client, null: false, foreign_key: true, type: :uuid

      t.string :nom, limit: 100, null: false
      t.string :prenom, limit: 100
      t.string :fonction, limit: 100
      t.string :email
      t.string :telephone, limit: 20
      t.boolean :principal, null: false, default: false

      t.timestamps
    end

    add_index :contacts, [:organisation_id, :client_id]
    add_index :contacts, [:client_id, :principal]
    add_index :contacts, :email
  end
end