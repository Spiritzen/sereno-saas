# frozen_string_literal: true

require "rails_helper"

RSpec.describe EvenementDevis, type: :model do
  describe "append-only" do
    it "interdit la modification d'un événement existant" do
      evenement = create(:evenement_devis)

      expect(evenement.update(statut: "envoye")).to be(false)
    end

    it "interdit la suppression d'un événement existant" do
      evenement = create(:evenement_devis)

      expect do
        evenement.destroy!
      end.to raise_error(ActiveRecord::RecordNotDestroyed)
    end
  end

  describe "isolation" do
    it "refuse un devis d'une autre organisation" do
      autre_organisation = create(:organisation)
      devis = create(:devis)

      evenement = build(:evenement_devis, organisation: autre_organisation, devis: devis)

      expect(evenement).not_to be_valid
      expect(evenement.errors[:devis]).to be_present
    end

    it "refuse un utilisateur d'une autre organisation" do
      organisation = create(:organisation)
      devis = create(:devis, organisation: organisation, client: create(:client, organisation: organisation))
      autre_utilisateur = create(:utilisateur)

      evenement = build(:evenement_devis, organisation: organisation, devis: devis, utilisateur: autre_utilisateur)

      expect(evenement).not_to be_valid
      expect(evenement.errors[:utilisateur]).to be_present
    end
  end

  describe "source fermée" do
    it "n'accepte que la source interne" do
      evenement = build(:evenement_devis, source: "pa")

      expect(evenement).not_to be_valid
      expect(evenement.errors[:source]).to be_present
    end
  end
end
