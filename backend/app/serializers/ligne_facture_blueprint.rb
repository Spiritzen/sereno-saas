# frozen_string_literal: true

class LigneFactureBlueprint < Blueprinter::Base
  identifier :id

  fields :facture_id,
         :produit_id,
         :designation,
         :quantite,
         :prix_unitaire_ht,
         :taux_tva,
         :montant_tva,
         :total_ht,
         :total_ttc,
         :position

  field :created_at do |ligne|
    ligne.created_at&.iso8601
  end

  field :updated_at do |ligne|
    ligne.updated_at&.iso8601
  end
end
