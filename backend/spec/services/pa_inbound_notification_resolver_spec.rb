# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaInboundNotificationResolver do
  describe ".call" do
    it "retrouve la transmission, sa plateforme, sa facture et son organisation via identifiant_pa" do
      organisation = create(:organisation)
      plateforme = create(:plateforme_agreee, organisation: organisation)
      facture = create(:facture, :deposee, organisation: organisation)
      transmission = create(
        :transmission_pa, :depose, organisation: organisation, facture: facture, plateforme_agreee: plateforme
      )

      resultat = described_class.call(identifiant_pa: transmission.identifiant_pa)

      expect(resultat).to be_present
      expect(resultat.transmission).to eq(transmission)
      expect(resultat.plateforme_agreee).to eq(plateforme)
      expect(resultat.facture).to eq(facture)
      expect(resultat.organisation).to eq(organisation)
    end

    it "retourne nil quand identifiant_pa est absent" do
      expect(described_class.call(identifiant_pa: nil)).to be_nil
      expect(described_class.call(identifiant_pa: "")).to be_nil
    end

    it "retourne nil quand aucune transmission ne correspond" do
      expect(described_class.call(identifiant_pa: "INCONNU")).to be_nil
    end

    it "ne rattache jamais deux organisations différentes au même identifiant_pa (unicité DB)" do
      organisation_a = create(:organisation)
      plateforme_a = create(:plateforme_agreee, organisation: organisation_a)
      facture_a = create(:facture, :deposee, organisation: organisation_a)
      transmission_a = create(
        :transmission_pa, :depose, organisation: organisation_a, facture: facture_a, plateforme_agreee: plateforme_a
      )

      organisation_b = create(:organisation)
      plateforme_b = create(:plateforme_agreee, organisation: organisation_b)
      facture_b = create(:facture, :deposee, organisation: organisation_b)
      transmission_b = build(
        :transmission_pa, :depose,
        organisation: organisation_b, facture: facture_b, plateforme_agreee: plateforme_b,
        identifiant_pa: transmission_a.identifiant_pa
      )

      expect { transmission_b.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
