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

  # V1.2c — miroir du XOR déjà testé sur TransmissionPa.
  describe "document (facture XOR avoir, V1.2c)" do
    it "accepte un événement rattaché à un avoir, et #document renvoie cet avoir" do
      avoir = create(:avoir, :deposee)
      transmission = create(:transmission_pa, :depose_avoir, organisation: avoir.organisation, avoir: avoir)

      evenement = build(
        :evenement_entrant_pa,
        organisation: avoir.organisation,
        transmission_pa: transmission,
        facture: nil,
        avoir: avoir
      )

      expect(evenement).to be_valid
      expect(evenement.document).to eq(avoir)
    end

    it "refuse un événement sans AUCUN document cible" do
      transmission = create(:transmission_pa, :depose)

      evenement = build(
        :evenement_entrant_pa,
        organisation: transmission.organisation,
        transmission_pa: transmission,
        facture: nil,
        avoir: nil
      )

      expect(evenement).not_to be_valid
      expect(evenement.errors[:base]).to be_present
    end

    it "refuse un événement rattaché À LA FOIS à une facture et à un avoir" do
      transmission = create(:transmission_pa, :depose)
      avoir = create(:avoir, :deposee, organisation: transmission.organisation)

      evenement = build(
        :evenement_entrant_pa,
        organisation: transmission.organisation,
        transmission_pa: transmission,
        facture: transmission.facture,
        avoir: avoir
      )

      expect(evenement).not_to be_valid
      expect(evenement.errors[:base]).to be_present
    end
  end
end
