# frozen_string_literal: true

# Miroir de LigneFactureBlueprint (ligne_devis a montant_tva/total_ttc
# depuis l'étage A — branchée sur FactureTotalsService).
class LigneDevisBlueprint < Blueprinter::Base
  identifier :id

  fields :devis_id,
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
