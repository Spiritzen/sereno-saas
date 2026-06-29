# frozen_string_literal: true

require "rails_helper"

RSpec.describe FactureConformiteService, type: :service do
  describe "#call" do
    it "considère conforme une facture brouillon complète" do
      facture = create(:facture, :avec_ligne)

      resultat = described_class.new(facture: facture.reload).call

      expect(resultat).to be_conforme
      expect(resultat.erreurs).to be_empty
    end

    it "bloque une facture sans ligne" do
      facture = create(:facture)

      resultat = described_class.new(facture: facture).call

      expect(resultat).not_to be_conforme
      expect(resultat.erreurs).to include("La facture doit contenir au moins une ligne")
    end

    it "bloque une organisation émettrice sans SIRET" do
  facture = create(:facture, :avec_ligne)

  facture.organisation.siret = nil

  resultat = described_class.new(facture: facture).call

  expect(resultat).not_to be_conforme
  expect(resultat.erreurs).to include("L'organisation émettrice doit avoir un SIRET")
end

    it "bloque un client public sans SIRET ni routage PA" do
      facture = create(:facture, :avec_ligne)

      facture.client.update_columns(
        type: "public",
        siret: nil,
        identifiant_routage_pa: nil
      )

      resultat = described_class.new(facture: facture.reload).call

      expect(resultat).not_to be_conforme
      expect(resultat.erreurs).to include("Le client public doit avoir un SIRET")
      expect(resultat.erreurs).to include("Le client public doit avoir un identifiant de routage PA")
    end

    it "bloque une organisation en franchise de TVA avec une facture contenant de la TVA" do
      facture = create(:facture, :avec_ligne)

      facture.organisation.update_columns(
        regime_tva: "franchise",
        numero_tva: nil
      )

      resultat = described_class.new(facture: facture.reload).call

      expect(resultat).not_to be_conforme
      expect(resultat.erreurs).to include("Une organisation en franchise de TVA ne peut pas émettre une facture avec de la TVA")
    end
  end
end
