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

    # Transmission déjà déposée (accusé PA reçu) : point de départ des tests
    # d'ingestion des statuts entrants (B3.1a).
    trait :depose do
      facture { association(:facture, :deposee, organisation: organisation) }
      statut { "depose" }
      identifiant_pa { "SANDBOX-#{SecureRandom.hex(8)}" }
      transmis_at { Time.current }
    end
  end
end
