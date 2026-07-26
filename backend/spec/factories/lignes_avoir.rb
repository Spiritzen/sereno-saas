# frozen_string_literal: true

FactoryBot.define do
  factory :ligne_avoir do
    avoir
    organisation { avoir.organisation }

    designation { "Prestation de test" }
    quantite { 2 }
    prix_unitaire_ht { 100 }
    taux_tva { 20 }
    position { 1 }
  end
end
