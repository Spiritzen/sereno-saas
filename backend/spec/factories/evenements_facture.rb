# frozen_string_literal: true

FactoryBot.define do
  factory :evenement_facture do
    organisation
    utilisateur { association(:utilisateur, organisation: organisation) }
    facture { association(:facture, :emise, organisation: organisation) }

    statut { "emise" }
    source { "interne" }
    code_statut_pa { nil }
    payload do
      {
        action: "emission_facture",
        numero: facture.numero
      }
    end
  end
end
