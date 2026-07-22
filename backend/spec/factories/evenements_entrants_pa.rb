# frozen_string_literal: true

FactoryBot.define do
  factory :evenement_entrant_pa do
    organisation
    transmission_pa { association(:transmission_pa, :depose, organisation: organisation) }
    facture { transmission_pa.facture }

    provider { "sandbox" }
    provider_event_id { nil }
    cle_deduplication { SecureRandom.hex(16) }

    statut_brut { "SANDBOX_RECEIVED" }
    statut_candidat { "recue" }

    occurred_at { Time.current }
    received_at { Time.current }

    payload { { simulation: true } }

    resultat { "applied" }
    motif { nil }
  end
end
