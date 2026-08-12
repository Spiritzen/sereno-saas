# frozen_string_literal: true

require "rails_helper"

RSpec.describe Facture, type: :model do
  describe "immutabilité après émission" do
    it "interdit la modification des totaux d'une facture émise" do
      facture = create(:facture, :emise)

      expect do
        facture.update!(total_ht: facture.total_ht + 10)
      end.to raise_error(ActiveRecord::RecordInvalid, /Une facture émise est immuable/)
    end

    it "interdit la modification des mentions d'une facture émise" do
      facture = create(:facture, :emise)

      expect do
        facture.update!(mentions: "Modification interdite")
      end.to raise_error(ActiveRecord::RecordInvalid, /Une facture émise est immuable/)
    end

    it "interdit la modification de pdf_url après émission" do
      facture = create(:facture, :emise)

      expect do
        facture.update!(pdf_url: "hack.pdf")
      end.to raise_error(ActiveRecord::RecordInvalid, /Une facture émise est immuable/)
    end

    it "interdit la modification de xml_url après émission" do
      facture = create(:facture, :emise)

      expect do
        facture.update!(xml_url: "hack.xml")
      end.to raise_error(ActiveRecord::RecordInvalid, /Une facture émise est immuable/)
    end

    it "interdit la modification d'une ligne de facture après émission" do
      facture = create(:facture, :emise)
      ligne = facture.lignes_facture.first

      expect(ligne).to be_present

      expect do
        ligne.update!(designation: "Modification interdite")
      end.to raise_error(ActiveRecord::RecordInvalid, /ne peut plus être modifiée après émission/)
    end
  end

  describe "#relancable? (relances v1a — 3 conditions, chaque branche)" do
    it "est fausse sur une facture en brouillon (statut non relançable)" do
      facture = create(:facture, date_echeance: 1.day.ago)

      expect(facture.relancable?).to be(false)
    end

    it "est fausse sur une facture émise mais annulée (statut terminal)" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)
      facture.update_columns(statut: "annulee")

      expect(facture.relancable?).to be(false)
    end

    it "est fausse sur une facture émise dont l'échéance n'est pas dépassée" do
      facture = create(:facture, :emise, date_echeance: 30.days.from_now)

      expect(facture.relancable?).to be(false)
    end

    it "est fausse sur une facture émise et échue mais déjà entièrement payée (reste_a_payer = 0)" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)
      create(:paiement, :confirme, facture: facture, organisation: facture.organisation, montant: facture.total_ttc)

      expect(facture.relancable?).to be(false)
    end

    it "est vraie sur une facture émise, échue et impayée" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)

      expect(facture.relancable?).to be(true)
    end

    it "est vraie sur une facture partiellement payée mais encore due" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)
      create(:paiement, :confirme, facture: facture, organisation: facture.organisation, montant: facture.total_ttc - 10)

      expect(facture.relancable?).to be(true)
    end
  end

  describe "#derniere_relance_at / #relances_count (dérivés, append-only)" do
    it "renvoie nil et 0 sans aucune relance" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)

      expect(facture.derniere_relance_at).to be_nil
      expect(facture.relances_count).to eq(0)
    end

    it "ignore les échecs pour derniere_relance_at mais les compte dans relances_count" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)
      create(:relance, facture: facture, organisation: facture.organisation, statut: "echec", envoyee_at: nil, mode_livraison: "smtp")
      envoyee = create(:relance, facture: facture, organisation: facture.organisation, envoyee_at: 1.hour.ago)

      expect(facture.derniere_relance_at).to be_within(1.second).of(envoyee.envoyee_at)
      expect(facture.relances_count).to eq(2)
    end
  end
end
