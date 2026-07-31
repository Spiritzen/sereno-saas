# frozen_string_literal: true

FactoryBot.define do
  factory :evenement_paiement do
    organisation
    utilisateur { association(:utilisateur, organisation: organisation) }
    paiement { association(:paiement, organisation: organisation) }

    statut { "brouillon" }
    source { "interne" }
    payload do
      { action: "paiement_cree" }
    end
  end
end
