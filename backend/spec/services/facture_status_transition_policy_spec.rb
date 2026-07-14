# frozen_string_literal: true

require "rails_helper"

RSpec.describe FactureStatusTransitionPolicy do
  def call(statut_facture_actuel:, statut_candidat:, occurred_at: 1.hour.ago, dernier_occurred_at_applique: nil)
    described_class.call(
      statut_facture_actuel: statut_facture_actuel,
      statut_candidat: statut_candidat,
      occurred_at: occurred_at,
      dernier_occurred_at_applique: dernier_occurred_at_applique
    )
  end

  describe "règle 1 — mapping impossible" do
    it "renvoie unmapped quel que soit le statut actuel" do
      decision = call(statut_facture_actuel: "deposee", statut_candidat: nil)

      expect(decision.resultat).to eq("unmapped")
      expect(decision.motif).to be_present
    end
  end

  describe "règle 2 — garde temporelle (AVANT la table)" do
    it "classe stale un message dont l'occurred_at est antérieur au dernier appliqué, MÊME SI la transition est valide" do
      decision = call(
        statut_facture_actuel: "en_litige",
        statut_candidat: "approuvee", # en_litige -> approuvee est POURTANT une transition valide
        occurred_at: 10.minutes.ago,
        dernier_occurred_at_applique: 5.minutes.ago
      )

      expect(decision.resultat).to eq("stale")
    end

    it "applique normalement quand aucun occurred_at de référence n'existe encore (première observation)" do
      decision = call(
        statut_facture_actuel: "deposee",
        statut_candidat: "recue",
        occurred_at: 1.minute.ago,
        dernier_occurred_at_applique: nil
      )

      expect(decision.resultat).to eq("applied")
    end

    it "applique normalement quand occurred_at est postérieur au dernier appliqué" do
      decision = call(
        statut_facture_actuel: "recue",
        statut_candidat: "mise_a_disposition",
        occurred_at: 1.minute.ago,
        dernier_occurred_at_applique: 10.minutes.ago
      )

      expect(decision.resultat).to eq("applied")
    end
  end

  describe "règle 3 — aucun changement de statut" do
    it "classe stale une observation confirmant le statut déjà courant" do
      decision = call(statut_facture_actuel: "approuvee", statut_candidat: "approuvee")

      expect(decision.resultat).to eq("stale")
      expect(decision.motif).to be_present
    end
  end

  describe "règle 4 — transition présente dans la table" do
    FactureStatusTransitionPolicy::TRANSITIONS.each do |depart, arrivees|
      arrivees.each do |arrivee|
        it "accepte #{depart} -> #{arrivee}" do
          decision = call(statut_facture_actuel: depart, statut_candidat: arrivee)

          expect(decision.resultat).to eq("applied")
        end
      end
    end

    it "accepte un saut avant (deposee -> approuvee) sans exiger les étapes intermédiaires" do
      decision = call(statut_facture_actuel: "deposee", statut_candidat: "approuvee")

      expect(decision.resultat).to eq("applied")
    end
  end

  describe "règle 5 — transition absente de la table" do
    context "depuis un statut TERMINAL" do
      FactureStatusTransitionPolicy::TERMINAUX.each do |terminal|
        it "classe requires_review une contradiction depuis #{terminal}" do
          statut_candidat = (Facture::STATUTS - [ terminal ]).first

          decision = call(statut_facture_actuel: terminal, statut_candidat: statut_candidat)

          expect(decision.resultat).to eq("requires_review")
          expect(decision.motif).to be_present
        end
      end
    end

    context "depuis un statut NON terminal (régression simple)" do
      it "classe stale une régression (ex. approuvee -> recue)" do
        decision = call(statut_facture_actuel: "approuvee", statut_candidat: "recue")

        expect(decision.resultat).to eq("stale")
        expect(decision.motif).to be_present
      end

      it "classe stale une régression (ex. mise_a_disposition -> deposee)" do
        decision = call(statut_facture_actuel: "mise_a_disposition", statut_candidat: "deposee")

        expect(decision.resultat).to eq("stale")
      end
    end
  end

  it "la table des transitions est gelée (pas de configuration externe possible)" do
    expect(FactureStatusTransitionPolicy::TRANSITIONS).to be_frozen
  end
end
