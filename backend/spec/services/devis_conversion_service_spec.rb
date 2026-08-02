# frozen_string_literal: true

require "rails_helper"
require "fileutils"

RSpec.describe DevisConversionService, type: :service do
  let(:organisation) { create(:organisation) }
  let(:utilisateur) { create(:utilisateur, organisation: organisation) }
  let(:client) { create(:client, organisation: organisation) }

  def devis_accepte(organisation:, client:)
    devis = create(:devis, :avec_ligne, organisation: organisation, client: client)
    DevisStatutService.new(devis: devis, utilisateur: create(:utilisateur, organisation: organisation)).envoyer!
    DevisStatutService.new(devis: devis, utilisateur: create(:utilisateur, organisation: organisation)).accepter!
    devis.reload
  end

  describe "#call — conversion réussie (indiscernabilité)" do
    it "produit une facture ÉMISE avec numéro FAC, totaux identiques au centime, XML/PDF réels, liée au devis" do
      devis = create(:devis, organisation: organisation, client: client)
      create(:ligne_devis, devis: devis, organisation: organisation,
                            quantite: 3, prix_unitaire_ht: "19.99", taux_tva: 20)
      create(:ligne_devis, devis: devis, organisation: organisation,
                            quantite: 2, prix_unitaire_ht: "15.50", taux_tva: "5.5")
      DevisStatutService.new(devis: devis, utilisateur: utilisateur).envoyer!
      DevisStatutService.new(devis: devis, utilisateur: utilisateur).accepter!
      devis.reload

      totaux_devis = { ht: devis.total_ht, tva: devis.total_tva, ttc: devis.total_ttc }

      facture = described_class.new(devis: devis, utilisateur: utilisateur).call

      expect(facture.statut).to eq("emise")
      expect(facture.numero).to match(/\AFAC-#{Date.current.year}-\d{4}\z/)
      expect(facture.devis_id).to eq(devis.id)
      expect(facture.client_id).to eq(devis.client_id)

      # Même moteur de calcul (FactureTotalsService), donc même total au
      # centime — pas une coïncidence, une PREUVE : les lignes ont été
      # copiées puis recalculées par LigneFacture, pas les totaux eux-mêmes.
      expect(facture.total_ht).to eq(totaux_devis[:ht])
      expect(facture.total_tva).to eq(totaux_devis[:tva])
      expect(facture.total_ttc).to eq(totaux_devis[:ttc])

      expect(facture.pdf_url).to be_present
      expect(facture.xml_url).to be_present
      expect(File.exist?(Rails.root.join(facture.pdf_url))).to be(true)
      expect(File.exist?(Rails.root.join(facture.xml_url))).to be(true)

      expect(EvenementFacture.where(facture_id: facture.id, statut: "emise").count).to eq(1)

      evenement_conversion = EvenementDevis.where(devis_id: devis.id).order(:created_at).last
      expect(evenement_conversion.payload["action"]).to eq("devis_converti")
      expect(evenement_conversion.payload["facture_id"]).to eq(facture.id)
      expect(evenement_conversion.payload["facture_numero"]).to eq(facture.numero)
    ensure
      FileUtils.rm_rf(Rails.root.join("storage", Rails.env, "factures", facture&.id.to_s)) if defined?(facture) && facture
    end

    it "ne recopie JAMAIS la date_validite du devis comme échéance de la facture" do
      devis = devis_accepte(organisation: organisation, client: client)
      devis.update_columns(date_validite: 3.days.from_now.to_date)

      facture = described_class.new(devis: devis, utilisateur: utilisateur).call

      expect(facture.date_echeance).not_to eq(devis.date_validite)
      expect(facture.date_echeance).to be_nil # défaut d'une facture manuelle sans échéance précisée
    ensure
      FileUtils.rm_rf(Rails.root.join("storage", Rails.env, "factures", facture&.id.to_s)) if defined?(facture) && facture
    end
  end

  describe "#call — idempotence" do
    it "refuse de convertir un devis déjà converti, sans créer de 2e facture" do
      devis = devis_accepte(organisation: organisation, client: client)
      premiere_facture = described_class.new(devis: devis, utilisateur: utilisateur).call

      expect do
        described_class.new(devis: devis.reload, utilisateur: utilisateur).call
      end.to raise_error(DevisConversionService::ConversionImpossibleError, /déjà converti/)

      expect(Facture.where(devis_id: devis.id).count).to eq(1)
      expect(Facture.where(devis_id: devis.id).first.id).to eq(premiere_facture.id)
    ensure
      FileUtils.rm_rf(Rails.root.join("storage", Rails.env, "factures", premiere_facture&.id.to_s)) if defined?(premiere_facture) && premiere_facture
    end
  end

  describe "#call — éligibilité" do
    it "refuse de convertir un devis brouillon" do
      devis = create(:devis, :avec_ligne, organisation: organisation, client: client)

      expect do
        described_class.new(devis: devis, utilisateur: utilisateur).call
      end.to raise_error(DevisConversionService::ConversionImpossibleError, /doit être accepté/)

      expect(Facture.where(devis_id: devis.id).count).to eq(0)
    end

    it "refuse de convertir un devis envoyé (pas encore accepté)" do
      devis = create(:devis, :avec_ligne, organisation: organisation, client: client)
      DevisStatutService.new(devis: devis, utilisateur: utilisateur).envoyer!

      expect do
        described_class.new(devis: devis.reload, utilisateur: utilisateur).call
      end.to raise_error(DevisConversionService::ConversionImpossibleError, /doit être accepté/)

      expect(Facture.where(devis_id: devis.id).count).to eq(0)
    end

    it "refuse de convertir un devis refusé" do
      devis = create(:devis, :avec_ligne, organisation: organisation, client: client)
      DevisStatutService.new(devis: devis, utilisateur: utilisateur).envoyer!
      DevisStatutService.new(devis: devis.reload, utilisateur: utilisateur).refuser!

      expect do
        described_class.new(devis: devis.reload, utilisateur: utilisateur).call
      end.to raise_error(DevisConversionService::ConversionImpossibleError, /doit être accepté/)

      expect(Facture.where(devis_id: devis.id).count).to eq(0)
    end
  end

  describe "#call — rollback (fail-loud, transactionnel)" do
    it "annule TOUTE la transaction si l'émission échoue (devis accepté SANS ligne) : aucune facture orpheline" do
      devis = create(:devis, organisation: organisation, client: client) # pas de ligne
      DevisStatutService.new(devis: devis, utilisateur: utilisateur).envoyer!
      DevisStatutService.new(devis: devis.reload, utilisateur: utilisateur).accepter!
      devis.reload

      expect do
        described_class.new(devis: devis, utilisateur: utilisateur).call
      end.to raise_error(FactureEmissionService::EmissionImpossibleError)

      expect(Facture.where(devis_id: devis.id).count).to eq(0)
      expect(devis.reload.statut).to eq("accepte")
      expect(devis.converti?).to be(false)
      expect(EvenementDevis.where(devis_id: devis.id).pluck(:payload).map { |p| p["action"] })
        .not_to include("devis_converti")
    end
  end
end
