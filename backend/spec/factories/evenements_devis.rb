# frozen_string_literal: true

FactoryBot.define do
  factory :evenement_devis do
    organisation
    utilisateur { association(:utilisateur, organisation: organisation) }
    devis { association(:devis, organisation: organisation) }

    statut { "brouillon" }
    source { "interne" }
    payload do
      { action: "devis_cree" }
    end
  end
end
