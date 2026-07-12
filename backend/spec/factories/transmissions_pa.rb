# frozen_string_literal: true

FactoryBot.define do
  factory :transmission_pa do
    organisation
    facture { association(:facture, :emise, organisation: organisation) }
    plateforme_agreee { association(:plateforme_agreee, organisation: organisation) }

    direction { "sortant" }
    statut { "en_attente" }
    format { "factur_x" }
    tentative { 1 }
    idempotency_key { SecureRandom.uuid }
  end
end
