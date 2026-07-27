class AddAvoirSupportToEvenementEntrantPa < ActiveRecord::Migration[8.1]
  def change
    # V1.2c — généralisation du couloir d'ingestion (PaStatusIngestionService)
    # à l'avoir. Miroir exact du choix déjà fait sur transmission_pa :
    # facture_id devient optionnel, avoir_id apparaît, exactement un des deux
    # est requis (XOR porté par le modèle, pas par une contrainte DB — même
    # convention que TransmissionPa#un_seul_document_cible).
    change_column_null :evenement_entrant_pa, :facture_id, true

    add_reference :evenement_entrant_pa, :avoir, null: true, foreign_key: true, type: :uuid

    add_index :evenement_entrant_pa,
              [ :organisation_id, :avoir_id ],
              name: "index_evenement_entrant_pa_on_org_and_avoir"
  end
end
