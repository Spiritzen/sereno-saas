# frozen_string_literal: true

FactoryBot.define do
  factory :devis do
    organisation
    client { association(:client, organisation: organisation) }

    numero { nil }
    statut { "brouillon" }
    objet { "Devis de test" }
    date_emission { Date.current }
    date_validite { 30.days.from_now.to_date }
    total_ht { 0 }
    total_tva { 0 }
    total_ttc { 0 }
    conditions { nil }

    trait :avec_ligne do
      after(:create) do |devis|
        create(:ligne_devis, devis: devis, organisation: devis.organisation)
        devis.reload
      end
    end

    trait :envoye do
      after(:create) do |devis|
        create(:ligne_devis, devis: devis, organisation: devis.organisation) if devis.lignes_devis.empty?
        devis.reload

        numero = "DEV-#{Date.current.year}-#{format('%04d', rand(1000..9999))}"

        devis.update_columns(statut: "envoye", numero: numero, updated_at: Time.current)
      end
    end
  end
end
