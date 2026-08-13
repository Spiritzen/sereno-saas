# frozen_string_literal: true

require "rails_helper"

RSpec.describe RelanceCadenceService do
  describe "#niveau_du" do
    it "renvoie le niveau 1 dès J+7 après l'échéance" do
      facture = create(:facture, :emise, date_echeance: 8.days.ago)

      expect(described_class.new(facture: facture).niveau_du).to eq(1)
    end

    it "renvoie nil avant J+7 (palier pas encore atteint)" do
      facture = create(:facture, :emise, date_echeance: 5.days.ago)

      expect(described_class.new(facture: facture).niveau_du).to be_nil
    end

    it "renvoie le niveau 2 à J+15 une fois le niveau 1 auto envoyé et le cooldown écoulé" do
      facture = create(:facture, :emise, date_echeance: 16.days.ago)
      create(:relance, :planifiee,
             facture: facture, organisation: facture.organisation,
             niveau: 1, statut: "envoyee", envoyee_at: 9.days.ago)

      expect(described_class.new(facture: facture).niveau_du).to eq(2)
    end

    it "renvoie nil une fois le niveau 3 auto envoyé — échelle épuisée, pas de palier 4" do
      facture = create(:facture, :emise, date_echeance: 40.days.ago)
      create(:relance, :planifiee,
             facture: facture, organisation: facture.organisation,
             niveau: 3, statut: "envoyee", envoyee_at: 9.days.ago)

      expect(described_class.new(facture: facture).niveau_du).to be_nil
    end

    it "un rappel MANUEL récent retarde la relance auto (cooldown toutes origines confondues)" do
      facture = create(:facture, :emise, date_echeance: 10.days.ago)
      create(:relance, facture: facture, organisation: facture.organisation, envoyee_at: 2.days.ago)

      expect(described_class.new(facture: facture).niveau_du).to be_nil
    end

    it "un rappel AUTO récent retarde la relance auto suivante (cooldown)" do
      facture = create(:facture, :emise, date_echeance: 20.days.ago)
      create(:relance, :planifiee,
             facture: facture, organisation: facture.organisation,
             niveau: 1, statut: "envoyee", envoyee_at: 2.days.ago)

      expect(described_class.new(facture: facture).niveau_du).to be_nil
    end

    it "une relance en ÉCHEC n'écarte pas le palier (n'avance pas l'échelle, ne bloque pas le cooldown)" do
      facture = create(:facture, :emise, date_echeance: 8.days.ago)
      create(:relance, :planifiee,
             facture: facture, organisation: facture.organisation,
             niveau: 1, statut: "echec", envoyee_at: nil, mode_livraison: nil)

      expect(described_class.new(facture: facture).niveau_du).to eq(1)
    end

    it "renvoie nil pour une facture entièrement payée (relancable? délègue déjà ce garde-fou)" do
      facture = create(:facture, :emise, date_echeance: 30.days.ago)
      create(:paiement, :confirme, facture: facture, organisation: facture.organisation, montant: facture.total_ttc)

      expect(described_class.new(facture: facture).niveau_du).to be_nil
    end

    it "renvoie nil pour une facture brouillon (jamais émise)" do
      facture = create(:facture, date_echeance: 30.days.ago)

      expect(described_class.new(facture: facture).niveau_du).to be_nil
    end
  end
end
