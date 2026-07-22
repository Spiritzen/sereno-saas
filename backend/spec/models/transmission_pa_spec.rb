# frozen_string_literal: true

require "rails_helper"

RSpec.describe TransmissionPa, type: :model do
  describe "idempotence" do
    it "exige une idempotency_key" do
      transmission = build(:transmission_pa, idempotency_key: nil)

      expect(transmission).not_to be_valid
      expect(transmission.errors[:idempotency_key]).to be_present
    end

    it "refuse deux transmissions avec la même idempotency_key" do
      cle = SecureRandom.uuid
      create(:transmission_pa, idempotency_key: cle)

      doublon = build(:transmission_pa, idempotency_key: cle)

      expect(doublon).not_to be_valid
      expect(doublon.errors[:idempotency_key]).to be_present
    end
  end

  describe "contrainte XOR facture/avoir" do
    it "refuse une transmission sans facture ni avoir" do
      organisation = create(:organisation)
      plateforme = create(:plateforme_agreee, organisation: organisation)

      transmission = build(
        :transmission_pa,
        organisation: organisation,
        facture: nil,
        plateforme_agreee: plateforme
      )

      expect(transmission).not_to be_valid
    end
  end
end
