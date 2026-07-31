# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaiementSyntheseService, type: :service do
  let(:organisation) { create(:organisation) }

  def facture_a(total_ttc)
    facture = create(:facture, :emise, organisation: organisation)
    facture.update_columns(total_ttc: total_ttc)
    facture
  end

  describe "aucun avoir, aucun paiement" do
    it "reste_a_payer = total_ttc, statut non_payee" do
      facture = facture_a(100)

      resultat = described_class.new(facture: facture).call

      expect(resultat.reste_a_payer).to eq(BigDecimal("100"))
      expect(resultat.statut_encaissement_local).to eq("non_payee")
    end
  end

  describe "paiement partiel confirmé" do
    it "réduit le reste à payer et passe en partielle" do
      facture = facture_a(100)
      create(:paiement, :confirme, facture: facture, organisation: organisation, montant: 40)

      resultat = described_class.new(facture: facture).call

      expect(resultat.reste_a_payer).to eq(BigDecimal("60"))
      expect(resultat.statut_encaissement_local).to eq("partielle")
    end
  end

  describe "paiement brouillon (ne compte pas)" do
    it "n'affecte pas le reste à payer" do
      facture = facture_a(100)
      create(:paiement, facture: facture, organisation: organisation, montant: 40, statut: "brouillon")

      resultat = described_class.new(facture: facture).call

      expect(resultat.reste_a_payer).to eq(BigDecimal("100"))
      expect(resultat.statut_encaissement_local).to eq("non_payee")
    end
  end

  describe "paiement annulé (ne compte pas)" do
    it "n'affecte pas le reste à payer" do
      facture = facture_a(100)
      create(:paiement, :annule, facture: facture, organisation: organisation, montant: 40)

      resultat = described_class.new(facture: facture).call

      expect(resultat.reste_a_payer).to eq(BigDecimal("100"))
      expect(resultat.statut_encaissement_local).to eq("non_payee")
    end
  end

  describe "facture soldée exactement" do
    it "reste_a_payer = 0, statut soldee" do
      facture = facture_a(100)
      create(:paiement, :confirme, facture: facture, organisation: organisation, montant: 100)

      resultat = described_class.new(facture: facture).call

      expect(resultat.reste_a_payer).to eq(BigDecimal("0"))
      expect(resultat.statut_encaissement_local).to eq("soldee")
    end
  end

  describe "trop-perçu (paiements > reste dû)" do
    it "plafonne reste_a_payer à 0 sans devenir négatif, statut soldee" do
      facture = facture_a(100)
      create(:paiement, :confirme, facture: facture, organisation: organisation, montant: 130)

      resultat = described_class.new(facture: facture).call

      expect(resultat.reste_a_payer).to eq(BigDecimal("0"))
      expect(resultat.statut_encaissement_local).to eq("soldee")
    end
  end

  describe "composition avec un avoir déjà émis" do
    it "déduit d'abord l'avoir, puis les paiements confirmés" do
      facture = facture_a(100)
      avoir = create(:avoir, :emise, organisation: organisation, facture: facture, client: facture.client)
      avoir.update_columns(total_ttc: 20)

      create(:paiement, :confirme, facture: facture, organisation: organisation, montant: 30)

      resultat = described_class.new(facture: facture).call

      # 100 (TTC) - 20 (avoir émis) - 30 (paiement confirmé) = 50
      expect(resultat.reste_a_payer).to eq(BigDecimal("50"))
      expect(resultat.statut_encaissement_local).to eq("partielle")
    end

    it "ignore un avoir encore brouillon" do
      facture = facture_a(100)
      create(:avoir, organisation: organisation, facture: facture, client: facture.client, statut: "brouillon")

      resultat = described_class.new(facture: facture).call

      expect(resultat.reste_a_payer).to eq(BigDecimal("100"))
    end
  end

  describe "arrondi au centime" do
    it "arrondit le résultat en BigDecimal ROUND_HALF_UP" do
      facture = facture_a(BigDecimal("10.005"))
      create(:paiement, :confirme, facture: facture, organisation: organisation, montant: BigDecimal("3.002"))

      resultat = described_class.new(facture: facture).call

      expect(resultat.reste_a_payer).to eq(BigDecimal("7.01"))
    end
  end

  describe "isolation" do
    it "ne compte que les paiements/avoirs de la facture concernée" do
      facture_a1 = facture_a(100)
      facture_a2 = facture_a(100)

      create(:paiement, :confirme, facture: facture_a2, organisation: organisation, montant: 40)

      resultat = described_class.new(facture: facture_a1).call

      expect(resultat.reste_a_payer).to eq(BigDecimal("100"))
    end
  end
end
