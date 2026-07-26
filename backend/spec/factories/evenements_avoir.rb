# frozen_string_literal: true

FactoryBot.define do
  factory :evenement_avoir do
    organisation
    utilisateur { association(:utilisateur, organisation: organisation) }
    avoir { association(:avoir, organisation: organisation) }

    statut { "brouillon" }
    source { "interne" }
    code_statut_pa { nil }
    payload do
      { action: "avoir_cree" }
    end
  end
end
