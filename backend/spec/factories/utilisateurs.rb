# frozen_string_literal: true

FactoryBot.define do
  factory :utilisateur do
    organisation

    sequence(:email) { |n| "user#{n}@sereno-test.fr" }
    mot_de_passe_hash { BCrypt::Password.create("Sereno123!") }
    nom { "Test" }
    prenom { "User" }
    role { "owner" }
    actif { true }
  end
end
