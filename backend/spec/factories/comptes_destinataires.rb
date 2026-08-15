# frozen_string_literal: true

FactoryBot.define do
  factory :compte_destinataire do
    sequence(:email) { |n| "destinataire#{n}@test.fr" }

    transient do
      mot_de_passe { "motdepasse123" }
    end

    after(:build) do |compte, evaluator|
      compte.definir_mot_de_passe(evaluator.mot_de_passe)
    end
  end
end
