# frozen_string_literal: true

require "rails_helper"

RSpec.describe EvenementPaiement, type: :model do
  describe "append-only" do
    it "interdit la modification d'un événement existant" do
      evenement = create(:evenement_paiement)

      expect(evenement.update(statut: "confirme")).to be(false)
    end

    it "interdit la suppression d'un événement existant" do
      evenement = create(:evenement_paiement)

      expect do
        evenement.destroy!
      end.to raise_error(ActiveRecord::RecordNotDestroyed)
    end
  end

  describe "isolation" do
    it "refuse un paiement d'une autre organisation" do
      autre_organisation = create(:organisation)
      paiement = create(:paiement)

      evenement = build(:evenement_paiement, organisation: autre_organisation, paiement: paiement)

      expect(evenement).not_to be_valid
      expect(evenement.errors[:paiement]).to be_present
    end
  end
end
