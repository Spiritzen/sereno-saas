# frozen_string_literal: true

FactoryBot.define do
  factory :plateforme_agreee do
    organisation

    fournisseur { "sandbox" }
    type { "pa" }
    api_url { "https://sandbox.local/pa" }
    statut { "connecte" }
  end
end
