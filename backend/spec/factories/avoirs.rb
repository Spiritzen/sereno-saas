# frozen_string_literal: true

FactoryBot.define do
  factory :avoir do
    organisation
    client { association(:client, organisation: organisation) }
    facture { association(:facture, :emise, organisation: organisation, client: client) }

    motif { "Erreur de facturation" }
    statut { "brouillon" }
  end
end
