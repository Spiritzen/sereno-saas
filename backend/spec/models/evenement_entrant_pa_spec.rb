# frozen_string_literal: true

require "rails_helper"

RSpec.describe EvenementEntrantPa, type: :model do
  describe "append-only" do
    it "interdit la modification d'un événement entrant existant" do
      evenement = create(:evenement_entrant_pa)

      expect(evenement.update(statut_candidat: "refusee")).to be(false)
    end

    it "interdit la suppression d'un événement entrant existant" do
      evenement = create(:evenement_entrant_pa)

      expect do
        evenement.destroy!
      end.to raise_error(ActiveRecord::RecordNotDestroyed)
    end
  end

  describe "isolation tenant" do
    it "refuse un événement entrant dont la facture appartient à une autre organisation" do
      autre_organisation = create(:organisation)
      transmission = create(:transmission_pa, :depose)
      facture_autre_org = create(:facture, :deposee, organisation: autre_organisation)

      evenement = build(
        :evenement_entrant_pa,
        organisation: transmission.organisation,
        transmission_pa: transmission,
        facture: facture_autre_org
      )

      expect(evenement).not_to be_valid
      expect(evenement.errors[:facture]).to be_present
    end
  end
end
