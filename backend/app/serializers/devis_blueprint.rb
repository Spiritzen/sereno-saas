# frozen_string_literal: true

# Miroir de FactureBlueprint/AvoirBlueprint. Champs propres au devis :
# expire/converti (dérivés, jamais stockés — cf. Devis#expire?/#converti?)
# et facture_generee (RÉFÉRENCE uniquement : id + numéro, jamais d'url brute
# de PDF/XML — le frontend rappelle facturesApi avec cet id s'il veut plus).
class DevisBlueprint < Blueprinter::Base
  identifier :id

  fields :client_id,
         :numero,
         :objet,
         :statut,
         :total_ht,
         :total_tva,
         :total_ttc,
         :conditions

  field :date_emission do |devis|
    devis.date_emission&.iso8601
  end

  field :date_validite do |devis|
    devis.date_validite&.iso8601
  end

  field :expire do |devis|
    devis.expire?
  end

  field :converti do |devis|
    devis.converti?
  end

  field :facture_generee do |devis|
    facture = devis.facture_generee
    next nil if facture.blank?

    { id: facture.id, numero: facture.numero }
  end

  field :created_at do |devis|
    devis.created_at&.iso8601
  end

  field :updated_at do |devis|
    devis.updated_at&.iso8601
  end

  field :lignes_count do |devis|
    if devis.association(:lignes_devis).loaded?
      devis.lignes_devis.size
    else
      devis.lignes_devis.count
    end
  end

  view :with_details do
    association :client, blueprint: ClientBlueprint
    association :lignes_devis, blueprint: LigneDevisBlueprint
  end
end
