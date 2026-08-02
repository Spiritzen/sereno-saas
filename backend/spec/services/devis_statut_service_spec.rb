# frozen_string_literal: true

require "rails_helper"

RSpec.describe DevisStatutService, type: :service do
  let(:organisation) { create(:organisation) }
  let(:utilisateur) { create(:utilisateur, organisation: organisation) }
  let(:client) { create(:client, organisation: organisation) }
  let(:devis) { create(:devis, :avec_ligne, organisation: organisation, client: client) }
  let(:service) { described_class.new(devis: devis, utilisateur: utilisateur) }

  describe "#envoyer!" do
    it "transitionne brouillon -> envoye, tire un numéro DEV-ANNEE-xxxx et journalise" do
      service.envoyer!

      expect(devis.reload.statut).to eq("envoye")
      expect(devis.numero).to match(/\ADEV-#{Date.current.year}-\d{4}\z/)

      evenement = EvenementDevis.find_by(devis_id: devis.id)
      expect(evenement).to be_present
      expect(evenement.statut).to eq("envoye")
      expect(evenement.source).to eq("interne")
      expect(evenement.payload["action"]).to eq("devis_envoye")
    end

    it "n'a pas de numéro tant que le devis est en brouillon" do
      expect(devis.numero).to be_nil
    end

    it "tire des numéros CONSÉCUTIFS pour deux devis envoyés à la suite (même organisation)" do
      premier = create(:devis, :avec_ligne, organisation: organisation, client: client)
      second = create(:devis, :avec_ligne, organisation: organisation, client: client)

      described_class.new(devis: premier, utilisateur: utilisateur).envoyer!
      described_class.new(devis: second, utilisateur: utilisateur).envoyer!

      premier_suffixe = premier.reload.numero[-4..].to_i
      second_suffixe = second.reload.numero[-4..].to_i

      expect(second_suffixe).to eq(premier_suffixe + 1)
    end

    it "isole la numérotation par organisation (deux organisations démarrent chacune à leur propre séquence)" do
      autre_organisation = create(:organisation)
      autre_client = create(:client, organisation: autre_organisation)
      autre_utilisateur = create(:utilisateur, organisation: autre_organisation)
      autre_devis = create(:devis, :avec_ligne, organisation: autre_organisation, client: autre_client)

      service.envoyer!
      described_class.new(devis: autre_devis, utilisateur: autre_utilisateur).envoyer!

      # Séquences indépendantes par organisation : les deux démarrent à
      # DEV-2026-0001 chacune de leur côté (même format, compteurs
      # Numerotation distincts) — c'est la preuve de l'isolation, pas une
      # collision.
      expect(devis.reload.numero).to eq("DEV-#{Date.current.year}-0001")
      expect(autre_devis.reload.numero).to eq("DEV-#{Date.current.year}-0001")

      expect(
        Numerotation.where(organisation: organisation, type_document: "devis").sole.dernier_numero
      ).to eq(1)
      expect(
        Numerotation.where(organisation: autre_organisation, type_document: "devis").sole.dernier_numero
      ).to eq(1)

      evenement = EvenementDevis.find_by(devis_id: devis.id)
      expect(evenement.organisation_id).to eq(organisation.id)
    end

    it "refuse d'envoyer un devis déjà envoyé (transition non autorisée), sans tirer de nouveau numéro" do
      service.envoyer!
      numero_initial = devis.reload.numero

      expect { service.envoyer! }.to raise_error(DevisStatutService::TransitionInterditeError)
      expect(devis.reload.numero).to eq(numero_initial)
      expect(EvenementDevis.where(devis_id: devis.id).count).to eq(1)
    end
  end

  describe "#accepter!" do
    it "transitionne envoye -> accepte et journalise" do
      service.envoyer!

      service.accepter!

      expect(devis.reload.statut).to eq("accepte")
      expect(EvenementDevis.where(devis_id: devis.id).pluck(:statut)).to eq(%w[envoye accepte])
    end

    it "refuse d'accepter un devis encore brouillon (saut d'étape interdit)" do
      expect { service.accepter! }.to raise_error(DevisStatutService::TransitionInterditeError)
      expect(devis.reload.statut).to eq("brouillon")
      expect(EvenementDevis.where(devis_id: devis.id).count).to eq(0)
    end
  end

  describe "#refuser!" do
    it "transitionne envoye -> refuse et journalise" do
      service.envoyer!

      service.refuser!

      expect(devis.reload.statut).to eq("refuse")
      expect(EvenementDevis.where(devis_id: devis.id).pluck(:statut)).to eq(%w[envoye refuse])
    end

    it "refuse toute transition après un statut terminal (accepte)" do
      service.envoyer!
      service.accepter!

      expect { service.refuser! }.to raise_error(DevisStatutService::TransitionInterditeError)
      expect(devis.reload.statut).to eq("accepte")
    end

    it "refuse toute transition après un statut terminal (refuse)" do
      service.envoyer!
      service.refuser!

      expect { service.accepter! }.to raise_error(DevisStatutService::TransitionInterditeError)
      expect(devis.reload.statut).to eq("refuse")
    end
  end

  it "la table des transitions est gelée (pas de configuration externe possible)" do
    expect(DevisStatutService::TRANSITIONS).to be_frozen
  end
end
