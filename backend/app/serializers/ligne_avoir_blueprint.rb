# frozen_string_literal: true

# Miroir de LigneFactureBlueprint. ligne_avoir n'a ni montant_tva ni
# total_ttc en colonnes propres (contrairement à ligne_facture, cf. V1.2a) :
# on n'expose que ce qui existe réellement.
class LigneAvoirBlueprint < Blueprinter::Base
  identifier :id

  fields :avoir_id,
         :designation,
         :quantite,
         :prix_unitaire_ht,
         :taux_tva,
         :total_ht,
         :position

  field :created_at do |ligne|
    ligne.created_at&.iso8601
  end

  field :updated_at do |ligne|
    ligne.updated_at&.iso8601
  end
end
