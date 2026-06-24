class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions, id: :uuid do |t|
      t.references :utilisateur, null: false, foreign_key: true, type: :uuid
      t.references :organisation, null: false, foreign_key: true, type: :uuid

      t.string :refresh_token_hash, null: false
      t.string :user_agent
      t.string :ip_adresse, limit: 45
      t.datetime :expire_at, null: false
      t.datetime :revoque_at

      t.timestamps
    end

    add_index :sessions, :refresh_token_hash, unique: true
    add_index :sessions, [:utilisateur_id, :organisation_id]
    add_index :sessions, :expire_at
  end
end