# frozen_string_literal: true

require "rails_helper"

RSpec.describe Organisation, type: :model do
  describe "validation du SIRET" do
    it "est valide avec un SIRET de 14 chiffres" do
      organisation = build(:organisation, siret: "12345678901234")

      expect(organisation).to be_valid
    end

    it "est invalide avec un SIRET contenant des lettres" do
      organisation = build(:organisation, siret: "1234567890123A")

      expect(organisation).not_to be_valid
      expect(organisation.errors[:siret]).to include("doit être composé de 14 chiffres")
    end

    it "est invalide avec un SIRET de moins de 14 chiffres" do
      organisation = build(:organisation, siret: "1234567890123")

      expect(organisation).not_to be_valid
    end

    it "est invalide avec un SIRET de plus de 14 chiffres" do
      organisation = build(:organisation, siret: "123456789012345")

      expect(organisation).not_to be_valid
    end
  end
end
