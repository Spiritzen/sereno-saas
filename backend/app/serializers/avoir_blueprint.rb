# frozen_string_literal: true

# Miroir de FactureBlueprint. Champ propre à l'avoir : facture_numero (BT-25
# lisible côté API), pour que le frontend affiche « Avoir sur FAC-... » sans
# requête supplémentaire.
class AvoirBlueprint < Blueprinter::Base
  identifier :id

  fields :client_id,
         :facture_id,
         :numero,
         :motif,
         :statut,
         :total_ht,
         :total_tva,
         :total_ttc,
         :pdf_url,
         :xml_url

  field :facture_numero do |avoir|
    avoir.facture&.numero
  end

  field :date_emission do |avoir|
    avoir.date_emission&.iso8601
  end

  field :emis_at do |avoir|
    avoir.emis_at&.iso8601
  end

  field :created_at do |avoir|
    avoir.created_at&.iso8601
  end

  field :updated_at do |avoir|
    avoir.updated_at&.iso8601
  end

  field :lignes_count do |avoir|
    if avoir.association(:lignes_avoir).loaded?
      avoir.lignes_avoir.size
    else
      avoir.lignes_avoir.count
    end
  end

  view :with_lignes do
    association :lignes_avoir, blueprint: LigneAvoirBlueprint
  end

  view :with_details do
    association :client, blueprint: ClientBlueprint
    association :lignes_avoir, blueprint: LigneAvoirBlueprint
  end
end
