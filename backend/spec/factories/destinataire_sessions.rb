# frozen_string_literal: true

FactoryBot.define do
  factory :destinataire_session do
    compte_destinataire

    token_hash { Digest::SHA256.hexdigest(SecureRandom.hex(64)) }
    expire_at { 30.days.from_now }
    revoque_at { nil }
  end
end
