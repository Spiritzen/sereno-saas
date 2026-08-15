# frozen_string_literal: true

FactoryBot.define do
  factory :destinataire_client_link do
    transient do
      organisation { create(:organisation) }
    end

    compte_destinataire
    client { association(:client, organisation: organisation) }
    facture_preuve { association(:facture, :emise, organisation: organisation, client: client) }
    cree_via { "lien_portail" }
  end
end
