# frozen_string_literal: true

# Miroir d'AvoirBlueprint. methode_libelle est DÉRIVÉ de l'enum UNTDID 4461
# (Paiement::MOYENS), jamais stocké. Aucun champ interne superflu.
class PaiementBlueprint < Blueprinter::Base
  identifier :id

  fields :facture_id,
         :montant,
         :methode_code,
         :reference,
         :statut

  field :methode_libelle do |paiement|
    paiement.libelle_moyen
  end

  field :date_encaissement do |paiement|
    paiement.date_encaissement&.iso8601
  end

  field :created_at do |paiement|
    paiement.created_at&.iso8601
  end

  field :updated_at do |paiement|
    paiement.updated_at&.iso8601
  end
end
