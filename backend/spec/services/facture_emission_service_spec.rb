# frozen_string_literal: true

require "rails_helper"
require "fileutils"

RSpec.describe FactureEmissionService, type: :service do
  describe "#call" do
    it "bloque l'émission d'une facture non conforme" do
      facture = create(:facture)
      utilisateur = create(:utilisateur, organisation: facture.organisation)

      expect do
        described_class.new(facture: facture, utilisateur: utilisateur).call
      end.to raise_error(FactureEmissionService::EmissionImpossibleError)

      expect(facture.reload.numero).to be_nil
      expect(facture.reload.statut).to eq("brouillon")
      expect(EvenementFacture.where(facture_id: facture.id)).to be_empty
    end

    it "émet une facture conforme avec numéro, PDF, XML et événement" do
      facture = create(:facture, :avec_ligne)
      utilisateur = create(:utilisateur, organisation: facture.organisation)

      facture_emise = described_class.new(
        facture: facture,
        utilisateur: utilisateur
      ).call

      facture_emise.reload

      expect(facture_emise.statut).to eq("emise")
      expect(facture_emise.numero).to be_present
      expect(facture_emise.pdf_url).to be_present
      expect(facture_emise.xml_url).to be_present
      expect(File.exist?(Rails.root.join(facture_emise.pdf_url))).to be(true)
      expect(File.exist?(Rails.root.join(facture_emise.xml_url))).to be(true)
      expect(EvenementFacture.where(facture_id: facture_emise.id, statut: "emise").count).to eq(1)
    ensure
      FileUtils.rm_rf(Rails.root.join("storage", Rails.env, "factures", facture&.id.to_s)) if facture
    end
  end
end
