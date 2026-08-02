# frozen_string_literal: true

require "rails_helper"

RSpec.describe Devis, type: :model do
  let(:organisation) { create(:organisation) }
  let(:client) { create(:client, organisation: organisation) }

  describe "totaux (cohérence stricte avec la facture)" do
    it "calcule le total d'une ligne exactement comme LigneFacture (via FactureTotalsService, GELÉ)" do
      devis = create(:devis, organisation: organisation, client: client)
      ligne = create(:ligne_devis, devis: devis, organisation: organisation,
                                    quantite: 2, prix_unitaire_ht: 100, taux_tva: 20)

      expect(ligne.total_ht).to eq(BigDecimal("200.00"))
      expect(ligne.montant_tva).to eq(BigDecimal("40.00"))
      expect(ligne.total_ttc).to eq(BigDecimal("240.00"))
    end

    it "agrège les totaux du devis par ventilation TVA, comme une facture" do
      devis = create(:devis, organisation: organisation, client: client)
      create(:ligne_devis, devis: devis, organisation: organisation,
                            quantite: 2, prix_unitaire_ht: 100, taux_tva: 20)
      create(:ligne_devis, devis: devis, organisation: organisation,
                            quantite: 1, prix_unitaire_ht: 50, taux_tva: 10)

      devis.reload

      expect(devis.total_ht).to eq(BigDecimal("250.00"))
      expect(devis.total_tva).to eq(BigDecimal("45.00")) # 40 (20% de 200) + 5 (10% de 50)
      expect(devis.total_ttc).to eq(BigDecimal("295.00"))
    end

    it "arrondit un cas limite (99,995 -> 100,00) exactement comme une facture équivalente, ROUND_HALF_UP" do
      devis = create(:devis, organisation: organisation, client: client)
      create(:ligne_devis, devis: devis, organisation: organisation,
                            quantite: "3.5", prix_unitaire_ht: "28.57", taux_tva: 20)

      facture = create(:facture, organisation: organisation, client: client)
      create(:ligne_facture, facture: facture, organisation: organisation,
                              quantite: "3.5", prix_unitaire_ht: "28.57", taux_tva: 20)

      devis.reload
      facture.reload

      expect(devis.total_ht).to eq(BigDecimal("100.00"))
      expect(devis.total_ht).to eq(facture.total_ht)
      expect(devis.total_tva).to eq(facture.total_tva)
      expect(devis.total_ttc).to eq(facture.total_ttc)
    end

    it "produit le MÊME total qu'une facture équivalente sur un cas multi-lignes / multi-taux" do
      devis = create(:devis, organisation: organisation, client: client)
      create(:ligne_devis, devis: devis, organisation: organisation,
                            quantite: 3, prix_unitaire_ht: "19.99", taux_tva: 20)
      create(:ligne_devis, devis: devis, organisation: organisation,
                            quantite: 2, prix_unitaire_ht: "15.50", taux_tva: "5.5")

      facture = create(:facture, organisation: organisation, client: client)
      create(:ligne_facture, facture: facture, organisation: organisation,
                              quantite: 3, prix_unitaire_ht: "19.99", taux_tva: 20)
      create(:ligne_facture, facture: facture, organisation: organisation,
                              quantite: 2, prix_unitaire_ht: "15.50", taux_tva: "5.5")

      devis.reload
      facture.reload

      expect(devis.total_ht).to eq(facture.total_ht)
      expect(devis.total_tva).to eq(facture.total_tva)
      expect(devis.total_ttc).to eq(facture.total_ttc)
    end

    it "renvoie 0 pour un devis sans ligne" do
      devis = create(:devis, organisation: organisation, client: client)

      expect(devis.total_ht).to eq(BigDecimal("0"))
      expect(devis.total_tva).to eq(BigDecimal("0"))
      expect(devis.total_ttc).to eq(BigDecimal("0"))
    end
  end

  describe "#expire? (dérivé, jamais stocké)" do
    it "est vrai pour un devis envoyé dont la date de validité est dépassée" do
      devis = create(:devis, :envoye, organisation: organisation, client: client,
                                       date_validite: 1.day.ago.to_date)

      expect(devis.expire?).to be(true)
      expect(devis.reload.statut).to eq("envoye") # jamais réécrit en base
    end

    it "est faux pour un devis envoyé dont la date de validité n'est pas dépassée" do
      devis = create(:devis, :envoye, organisation: organisation, client: client,
                                       date_validite: 10.days.from_now.to_date)

      expect(devis.expire?).to be(false)
    end

    it "est faux pour un brouillon, même avec une date de validité dépassée" do
      devis = create(:devis, organisation: organisation, client: client,
                              statut: "brouillon", date_validite: 1.day.ago.to_date)

      expect(devis.expire?).to be(false)
    end

    it "est faux pour un devis accepté, même avec une date de validité dépassée (statut terminal)" do
      devis = create(:devis, :envoye, organisation: organisation, client: client,
                                       date_validite: 1.day.ago.to_date)
      devis.update_columns(statut: "accepte")

      expect(devis.expire?).to be(false)
    end

    it "est faux sans date de validité renseignée" do
      devis = create(:devis, :envoye, organisation: organisation, client: client, date_validite: nil)

      expect(devis.expire?).to be(false)
    end
  end

  describe "#converti? / #facture_generee (idempotence)" do
    it "est faux pour un devis n'ayant produit aucune facture" do
      devis = create(:devis, organisation: organisation, client: client)

      expect(devis.converti?).to be(false)
      expect(devis.facture_generee).to be_nil
    end

    it "est vrai dès qu'une facture référence ce devis, quel que soit le chemin de rattachement" do
      devis = create(:devis, organisation: organisation, client: client)
      facture = create(:facture, organisation: organisation, client: client, devis: devis)

      expect(devis.reload.converti?).to be(true)
      expect(devis.facture_generee).to eq(facture)
    end
  end
end
