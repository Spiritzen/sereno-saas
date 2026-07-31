# frozen_string_literal: true

require "rails_helper"

RSpec.describe Paiement, type: :model do
  # NOTE : build(:paiement, ...) seul ne suffit pas pour ces tests — FactoryBot
  # propage la stratégie "build" à l'association facture (use_parent_strategy),
  # ce qui empêche le after(:create) du trait :emise de tourner et laisse la
  # facture en "brouillon". On crée donc explicitement une facture éligible et
  # on la passe, pour tester UNIQUEMENT les validations de contenu ici.
  describe "validations de base" do
    let(:facture_eligible) { create(:facture, :emise) }

    it "refuse un montant nul ou négatif" do
      paiement = build(:paiement, facture: facture_eligible, organisation: facture_eligible.organisation, montant: 0)
      expect(paiement).not_to be_valid
      expect(paiement.errors[:montant]).to be_present

      paiement = build(:paiement, facture: facture_eligible, organisation: facture_eligible.organisation, montant: -10)
      expect(paiement).not_to be_valid
    end

    it "refuse un methode_code hors nomenclature UNTDID 4461" do
      paiement = build(:paiement, facture: facture_eligible, organisation: facture_eligible.organisation, methode_code: "99")

      expect(paiement).not_to be_valid
      expect(paiement.errors[:methode_code]).to be_present
    end

    it "accepte chacun des 5 codes retenus" do
      %w[10 20 48 58 59].each do |code|
        paiement = build(:paiement, facture: facture_eligible, organisation: facture_eligible.organisation, methode_code: code)
        expect(paiement).to be_valid, "#{code} devrait être un methode_code valide"
      end
    end
  end

  describe "éligibilité de la facture (facture émise ET non annulée)" do
    it "refuse un paiement sur une facture encore en brouillon" do
      facture = create(:facture)
      paiement = build(:paiement, facture: facture, organisation: facture.organisation)

      expect(paiement).not_to be_valid
      expect(paiement.errors[:facture]).to be_present
    end

    it "refuse un paiement sur une facture annulée" do
      facture = create(:facture, :emise)
      facture.update_columns(statut: "annulee")

      paiement = build(:paiement, facture: facture, organisation: facture.organisation)

      expect(paiement).not_to be_valid
      expect(paiement.errors[:facture]).to be_present
    end

    it "accepte un paiement sur une facture émise" do
      facture = create(:facture, :emise)
      paiement = build(:paiement, facture: facture, organisation: facture.organisation)

      expect(paiement).to be_valid
    end
  end

  describe "isolation organisation" do
    it "refuse un paiement dont l'organisation diffère de celle de la facture" do
      autre_organisation = create(:organisation)
      facture = create(:facture, :emise)

      paiement = build(:paiement, facture: facture, organisation: autre_organisation)

      expect(paiement).not_to be_valid
      expect(paiement.errors[:facture]).to be_present
    end
  end

  describe "machine de statuts (append-only après confirmation)" do
    it "autorise brouillon -> confirme" do
      paiement = create(:paiement, statut: "brouillon")

      expect(paiement.update(statut: "confirme")).to be(true)
    end

    it "autorise confirme -> annule" do
      paiement = create(:paiement, :confirme)

      expect(paiement.update(statut: "annule")).to be(true)
    end

    it "refuse confirme -> brouillon (pas de retour en arrière)" do
      paiement = create(:paiement, :confirme)

      expect(paiement.update(statut: "brouillon")).to be(false)
    end

    it "refuse toute transition depuis annule (statut terminal)" do
      paiement = create(:paiement, :annule)

      expect(paiement.update(statut: "confirme")).to be(false)
      expect(paiement.update(statut: "brouillon")).to be(false)
    end

    it "verrouille les champs de contenu après confirmation (422 modèle)" do
      paiement = create(:paiement, :confirme)

      expect(paiement.update(montant: paiement.montant + 1)).to be(false)
      expect(paiement.errors[:base]).to be_present
    end

    it "verrouille les champs de contenu même une fois annulé" do
      paiement = create(:paiement, :annule)

      expect(paiement.update(reference: "modifie")).to be(false)
    end

    it "n'empêche pas de modifier un paiement encore brouillon" do
      paiement = create(:paiement, statut: "brouillon")

      expect(paiement.update(montant: paiement.montant + 1)).to be(true)
    end
  end

  describe "destruction (jamais un destroy pour un paiement réel)" do
    it "autorise la destruction d'un paiement brouillon" do
      paiement = create(:paiement, statut: "brouillon")

      expect { paiement.destroy! }.not_to raise_error
    end

    it "interdit la destruction d'un paiement confirmé" do
      paiement = create(:paiement, :confirme)

      expect { paiement.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
    end

    it "interdit la destruction d'un paiement annulé" do
      paiement = create(:paiement, :annule)

      expect { paiement.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
    end
  end

  describe "aucune mutation de Facture (anti-pattern du mort, cf. rapportReconnaissancev1.txt)" do
    it "n'écrit jamais facture.statut ni facture.montant_paye à la création" do
      facture = create(:facture, :emise)
      statut_avant = facture.statut
      montant_paye_avant = facture.montant_paye

      create(:paiement, :confirme, facture: facture, organisation: facture.organisation)

      expect(facture.reload.statut).to eq(statut_avant)
      expect(facture.reload.montant_paye).to eq(montant_paye_avant)
    end

    it "n'écrit jamais facture.statut ni facture.montant_paye à la confirmation/annulation" do
      facture = create(:facture, :emise)
      paiement = create(:paiement, facture: facture, organisation: facture.organisation)

      paiement.update!(statut: "confirme")
      paiement.update!(statut: "annule")

      expect(facture.reload.statut).to eq("emise")
      expect(facture.reload.montant_paye).to eq(0)
    end
  end
end
