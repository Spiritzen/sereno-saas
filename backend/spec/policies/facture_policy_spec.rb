# frozen_string_literal: true

require "rails_helper"

RSpec.describe FacturePolicy do
  after do
    Current.reset
  end

  describe "#emettre?" do
    it "autorise un owner à émettre une facture brouillon de son organisation" do
      organisation = create(:organisation)
      utilisateur = create(:utilisateur, organisation: organisation, role: "owner")
      facture = create(:facture, :avec_ligne, organisation: organisation)

      Current.organisation = organisation
      Current.utilisateur = utilisateur

      policy = described_class.new(utilisateur, facture)

      expect(policy.emettre?).to be(true)
    end

    it "refuse l'émission d'une facture déjà émise" do
      organisation = create(:organisation)
      utilisateur = create(:utilisateur, organisation: organisation, role: "owner")
      facture = create(:facture, :emise, organisation: organisation)

      Current.organisation = organisation
      Current.utilisateur = utilisateur

      policy = described_class.new(utilisateur, facture)

      expect(policy.emettre?).to be(false)
    end

    it "refuse l'émission d'une facture d'une autre organisation" do
      organisation_a = create(:organisation)
      organisation_b = create(:organisation)

      utilisateur = create(:utilisateur, organisation: organisation_a, role: "owner")
      facture = create(:facture, :avec_ligne, organisation: organisation_b)

      Current.organisation = organisation_a
      Current.utilisateur = utilisateur

      policy = described_class.new(utilisateur, facture)

      expect(policy.emettre?).to be(false)
    end
  end
end
