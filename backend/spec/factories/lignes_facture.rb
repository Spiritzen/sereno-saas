# frozen_string_literal: true

FactoryBot.define do
  factory :ligne_facture do
    facture
    organisation { facture.organisation }

    produit_id { nil }
    designation { "Prestation de test" }
    quantite { 2 }
    prix_unitaire_ht { 100 }
    taux_tva { 20 }
    position { 1 }
  end
end
