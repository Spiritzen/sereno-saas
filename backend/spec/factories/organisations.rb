# frozen_string_literal: true

FactoryBot.define do
  factory :organisation do
    sequence(:raison_sociale) { |n| "Studio Test #{n}" }
    sequence(:siret) { |n| (10_000_000_000_000 + n).to_s }
    sequence(:email) { |n| "contact#{n}@studio-test.fr" }

    forme_juridique { "SASU" }
    numero_tva { "FR00123456789" }
    regime_tva { "reel_normal" }
    adresse_ligne1 { "1 rue de la Paix" }
    adresse_ligne2 { nil }
    code_postal { "80000" }
    ville { "Amiens" }
    pays { "FR" }
    telephone { "0600000000" }
    iban { "FR7630001007941234567890185" }
    mentions_legales { "Indemnité forfaitaire pour frais de recouvrement : 40 €." }
    identifiant_pa { "PA-TEST" }
  end
end
