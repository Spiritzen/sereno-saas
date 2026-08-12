# frozen_string_literal: true

require "rails_helper"

RSpec.describe Relance, type: :model do
  describe "validations de base" do
    it "refuse une relance sans destinataire_email" do
      relance = build(:relance, destinataire_email: nil)

      expect(relance).not_to be_valid
      expect(relance.errors[:destinataire_email]).to be_present
    end

    it "refuse un destinataire_email mal formé" do
      relance = build(:relance, destinataire_email: "pas-un-email")

      expect(relance).not_to be_valid
      expect(relance.errors[:destinataire_email]).to be_present
    end

    it "refuse une relance sans objet" do
      relance = build(:relance, objet: nil)

      expect(relance).not_to be_valid
      expect(relance.errors[:objet]).to be_present
    end

    it "refuse un canal hors nomenclature" do
      relance = build(:relance, canal: "sms")

      expect(relance).not_to be_valid
    end

    it "refuse un statut hors nomenclature" do
      relance = build(:relance, statut: "en_cours")

      expect(relance).not_to be_valid
    end

    it "refuse un mode_livraison inconnu (quand renseigné)" do
      relance = build(:relance, mode_livraison: "fax")

      expect(relance).not_to be_valid
    end

    it "accepte un mode_livraison nil (avant tentative d'envoi par le service)" do
      # NOTE (cf. spec/models/paiement_spec.rb) : build(:relance) seul ne
      # suffit pas — FactoryBot propage la stratégie "build" à l'association
      # facture, qui reste alors en "brouillon" (non relancable). On crée
      # donc explicitement une facture éligible pour isoler UNIQUEMENT la
      # validation de mode_livraison ici.
      facture = create(:facture, :emise, date_echeance: 1.day.ago)
      relance = build(
        :relance,
        facture: facture,
        organisation: facture.organisation,
        mode_livraison: nil,
        statut: "planifiee",
        envoyee_at: nil
      )

      expect(relance).to be_valid
    end

    it "exige envoyee_at quand le statut est envoyee" do
      relance = build(:relance, statut: "envoyee", envoyee_at: nil)

      expect(relance).not_to be_valid
      expect(relance.errors[:envoyee_at]).to be_present
    end
  end

  describe "éligibilité de la facture (réutilise Facture#relancable?, jamais une 2e formule)" do
    it "refuse une relance sur une facture non éligible (brouillon)" do
      facture = create(:facture)
      relance = build(:relance, facture: facture, organisation: facture.organisation)

      expect(relance).not_to be_valid
      expect(relance.errors[:facture]).to be_present
    end

    it "refuse une relance sur une facture émise mais dont l'échéance n'est pas dépassée" do
      facture = create(:facture, :emise, date_echeance: 30.days.from_now)
      relance = build(:relance, facture: facture, organisation: facture.organisation)

      expect(relance).not_to be_valid
      expect(relance.errors[:facture]).to be_present
    end

    it "accepte une relance sur une facture émise, échue et impayée" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)
      relance = build(:relance, facture: facture, organisation: facture.organisation)

      expect(relance).to be_valid
    end
  end

  describe "origine / date_planifiee (exécution du 12/08/2026 — manuel v1a vs planifié v1b)" do
    it "une relance manuelle est valide SANS date_planifiee" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)
      relance = build(
        :relance,
        facture: facture,
        organisation: facture.organisation,
        origine: "manuel",
        date_planifiee: nil
      )

      expect(relance).to be_valid
    end

    it "une relance planifiée est INVALIDE sans date_planifiee" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)
      relance = build(
        :relance, :planifiee,
        facture: facture,
        organisation: facture.organisation,
        date_planifiee: nil
      )

      expect(relance).not_to be_valid
      expect(relance.errors[:date_planifiee]).to be_present
    end

    it "accepte une relance planifiée avec une date_planifiee renseignée" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)
      relance = build(:relance, :planifiee, facture: facture, organisation: facture.organisation)

      expect(relance).to be_valid
    end

    it "refuse une origine hors nomenclature {manuel, planifie}" do
      relance = build(:relance, origine: "automatique")

      expect(relance).not_to be_valid
      expect(relance.errors[:origine]).to be_present
    end

    it "distingue #planifiee? (statut de l'envoi) de #origine_planifiee? (qui a créé la ligne)" do
      manuelle_en_attente = build(:relance, origine: "manuel", statut: "planifiee", date_planifiee: nil, envoyee_at: nil)

      expect(manuelle_en_attente.planifiee?).to be(true)
      expect(manuelle_en_attente.origine_planifiee?).to be(false)
      expect(manuelle_en_attente.origine_manuelle?).to be(true)
    end
  end

  describe "isolation organisation" do
    it "refuse une relance dont l'organisation diffère de celle de la facture" do
      autre_organisation = create(:organisation)
      facture = create(:facture, :emise, date_echeance: 1.day.ago)

      relance = build(:relance, facture: facture, organisation: autre_organisation)

      expect(relance).not_to be_valid
      expect(relance.errors[:facture]).to be_present
    end

    it "refuse une relance dont l'utilisateur diffère de celle de l'organisation" do
      autre_organisation = create(:organisation)
      autre_utilisateur = create(:utilisateur, organisation: autre_organisation)
      facture = create(:facture, :emise, date_echeance: 1.day.ago)

      relance = build(:relance, facture: facture, organisation: facture.organisation, utilisateur: autre_utilisateur)

      expect(relance).not_to be_valid
      expect(relance.errors[:utilisateur]).to be_present
    end
  end

  describe "append-only" do
    it "interdit la modification d'une relance existante" do
      relance = create(:relance)

      expect(relance.update(objet: "Objet modifié")).to be(false)
      expect(relance.errors[:base]).to be_present
    end

    it "interdit la suppression d'une relance existante" do
      relance = create(:relance)

      expect do
        relance.destroy!
      end.to raise_error(ActiveRecord::RecordNotDestroyed)
    end
  end

  describe "#recentes" do
    it "ordonne les relances par envoyee_at décroissant" do
      facture = create(:facture, :emise, date_echeance: 1.day.ago)
      ancienne = create(:relance, facture: facture, organisation: facture.organisation, envoyee_at: 2.days.ago)
      recente = create(:relance, facture: facture, organisation: facture.organisation, envoyee_at: 1.hour.ago)

      expect(facture.relances.recentes.to_a).to eq([ recente, ancienne ])
    end
  end
end
