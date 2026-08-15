# frozen_string_literal: true

FactoryBot.define do
  factory :portail_facture_token do
    organisation
    facture { association(:facture, :emise, organisation: organisation, date_echeance: 1.day.ago) }

    # Un hash de token BRUT jamais utilisé par le code applicatif (celui-ci
    # ne résoudra jamais rien via .resoudre, qui recalcule son propre hash à
    # partir d'un brut) — cohérent avec le fait que le modèle ne stocke
    # QUE le hash, jamais le brut.
    token_hash { Digest::SHA256.hexdigest(SecureRandom.hex(64)) }
    expire_at { 12.months.from_now }
    revoque_at { nil }
  end
end
