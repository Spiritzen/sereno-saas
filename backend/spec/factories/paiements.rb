# frozen_string_literal: true

FactoryBot.define do
  factory :paiement do
    organisation
    facture { association(:facture, :emise, organisation: organisation) }

    montant { 100 }
    methode_code { "58" }
    date_encaissement { Date.current }
    reference { nil }
    statut { "brouillon" }

    trait :confirme do
      after(:create) do |paiement|
        paiement.update_columns(statut: "confirme", updated_at: Time.current)
      end
    end

    trait :annule do
      after(:create) do |paiement|
        paiement.update_columns(statut: "annule", updated_at: Time.current)
      end
    end
  end
end
