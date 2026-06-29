# frozen_string_literal: true

FactoryBot.define do
  factory :client do
    organisation

    add_attribute(:type) { "entreprise" }

    sequence(:raison_sociale) { |n| "Client Test #{n} SAS" }
    sequence(:siret) { |n| (20_000_000_000_000 + n).to_s }
    numero_tva { "FR12987654321" }
    adresse_ligne1 { "10 avenue des Tests" }
    adresse_ligne2 { nil }
    code_postal { "75001" }
    ville { "Paris" }
    pays { "FR" }
    email { "client@test.fr" }
    telephone { "0102030405" }
    identifiant_routage_pa { "ROUTAGE-TEST" }
    statut { "actif" }
    notes { nil }
  end
end
