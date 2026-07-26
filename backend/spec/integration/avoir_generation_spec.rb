# frozen_string_literal: true

require "rails_helper"
require "nokogiri"
require "bigdecimal"
require "active_support/testing/time_helpers"

# Garde-fou V1.2a (voie b) : preuve que l'avoir (TypeCode 381) référence sa
# facture (BT-25) et valide contre le MÊME XSD EN16931 vendoré que le 380
# (facturx_generation_spec.rb, GELÉ, jamais modifié ni relu ici au-delà de
# la lecture du XSD lui-même, commun aux deux TypeCode).
RSpec.describe "Génération avoir (381) — cœur backend V1.2a", type: :integration do
  include ActiveSupport::Testing::TimeHelpers

  # Nom distinct de facturx_generation_spec.rb (GELÉ) : les constantes
  # assignées dans un bloc RSpec.describe atterrissent au niveau top-level
  # Ruby (class_exec/instance_eval ne créent pas de scope de constante),
  # donc DATE_EMISSION_FIGEE tout court entrerait en collision.
  DATE_EMISSION_FIGEE_AVOIR = Date.new(2026, 1, 15)

  around do |example|
    travel_to(DATE_EMISSION_FIGEE_AVOIR) { example.run }
  end

  let(:organisation) { create(:organisation) }
  let(:client) { create(:client, organisation: organisation) }
  let(:utilisateur) { create(:utilisateur, organisation: organisation) }
  let(:facture) { create(:facture, :emise, organisation: organisation, client: client) }

  let(:avoir) { create(:avoir, organisation: organisation, client: client, facture: facture) }

  def ajouter_ligne_avoir(avoir, quantite: 2, prix_unitaire_ht: 100, taux_tva: 20)
    create(:ligne_avoir, avoir: avoir, organisation: avoir.organisation,
                          quantite: quantite, prix_unitaire_ht: prix_unitaire_ht, taux_tva: taux_tva)
  end

  after do
    FileUtils.rm_rf(Rails.root.join("storage", "factures", avoir.id.to_s))
  end

  describe "chemin heureux — avoir conforme référençant une facture émise" do
    before { ajouter_ligne_avoir(avoir) }

    it "T-EMISSION : émet l'avoir (numéro AV-ANNEE-xxxx, statut, XML+PDF, transaction)" do
      avoir_emis = AvoirEmissionService.new(avoir: avoir, utilisateur: utilisateur).call
      avoir_emis.reload

      expect(avoir_emis.statut).to eq("emise")
      expect(avoir_emis.numero).to match(/\AAV-#{Date.current.year}-\d{4}\z/)
      expect(avoir_emis.date_emission).to eq(DATE_EMISSION_FIGEE_AVOIR)
      expect(avoir_emis.pdf_url).to be_present
      expect(avoir_emis.xml_url).to be_present
      expect(File.size(Rails.root.join(avoir_emis.pdf_url))).to be > 0
      expect(File.size(Rails.root.join(avoir_emis.xml_url))).to be > 0
    end

    it "T-XML-381 (décisif) : le XML CII porte TypeCode 381, pas 380" do
      avoir_emis = AvoirEmissionService.new(avoir: avoir, utilisateur: utilisateur).call
      doc = Nokogiri::XML(File.read(Rails.root.join(avoir_emis.xml_url)))
      doc.remove_namespaces!

      expect(doc.at_xpath("//ExchangedDocument/TypeCode")&.text).to eq("381")
    end

    it "T-BT25 (décisif) : le XML référence le NUMÉRO EXACT de la facture corrigée" do
      avoir_emis = AvoirEmissionService.new(avoir: avoir, utilisateur: utilisateur).call
      doc = Nokogiri::XML(File.read(Rails.root.join(avoir_emis.xml_url)))
      doc.remove_namespaces!

      reference = doc.at_xpath("//ApplicableHeaderTradeSettlement/InvoiceReferencedDocument/IssuerAssignedID")

      expect(reference).to be_present
      expect(reference.text).to eq(facture.numero)

      # position normée (XSD) : après le résumé monétaire, dans le règlement.
      settlement = doc.at_xpath("//ApplicableHeaderTradeSettlement")
      enfants = settlement.elements.map(&:name)
      expect(enfants.index("InvoiceReferencedDocument")).to be > enfants.index("SpecifiedTradeSettlementHeaderMonetarySummation")
    end

    it "T-XSD-381 (décisif) : le XML de l'avoir valide contre le XSD EN16931 vendoré" do
      avoir_emis = AvoirEmissionService.new(avoir: avoir, utilisateur: utilisateur).call

      xsd_path = Rails.root.join("vendor", "facturx", "xsd", "en16931", "Factur-X_1.09_EN16931.xsd")
      schema = Nokogiri::XML::Schema.new(File.open(xsd_path))
      document = Nokogiri::XML(File.read(Rails.root.join(avoir_emis.xml_url)))

      erreurs = schema.validate(document)

      expect(erreurs.map(&:message)).to eq([])
    end

    it "cohérence des totaux au centime entre l'avoir et son XML" do
      avoir_emis = AvoirEmissionService.new(avoir: avoir, utilisateur: utilisateur).call
      avoir_emis.reload

      doc = Nokogiri::XML(File.read(Rails.root.join(avoir_emis.xml_url)))
      doc.remove_namespaces!

      grand_total = BigDecimal(doc.at_xpath("//SpecifiedTradeSettlementHeaderMonetarySummation/GrandTotalAmount").text)
      tax_total = BigDecimal(doc.at_xpath("//SpecifiedTradeSettlementHeaderMonetarySummation/TaxTotalAmount").text)

      expect(grand_total).to eq(BigDecimal(avoir_emis.total_ttc.to_s))
      expect(tax_total).to eq(BigDecimal(avoir_emis.total_tva.to_s))
      expect(avoir_emis.total_ht).to eq(BigDecimal("200.00"))
      expect(avoir_emis.total_tva).to eq(BigDecimal("40.00"))
      expect(avoir_emis.total_ttc).to eq(BigDecimal("240.00"))
    end
  end

  describe "chemin refusé — conformité" do
    it "T-CONFORMITE-KO : un avoir sans ligne est refusé, aucun artefact produit" do
      expect do
        AvoirEmissionService.new(avoir: avoir, utilisateur: utilisateur).call
      end.to raise_error(AvoirEmissionService::EmissionImpossibleError) { |erreur|
        expect(erreur.details.join(" ")).to include("L'avoir doit contenir au moins une ligne")
      }

      avoir.reload
      expect(avoir.statut).to eq("brouillon")
      expect(avoir.numero).to be_nil
      expect(avoir.pdf_url).to be_nil
      expect(avoir.xml_url).to be_nil
    end

    it "T-CONFORMITE-KO : un second avoir qui dépasserait le montant TTC de la facture est refusé" do
      ajouter_ligne_avoir(avoir, quantite: 2, prix_unitaire_ht: 100, taux_tva: 20) # 240 TTC = 100% de la facture
      AvoirEmissionService.new(avoir: avoir, utilisateur: utilisateur).call

      second_avoir = create(:avoir, organisation: organisation, client: client, facture: facture)
      ajouter_ligne_avoir(second_avoir, quantite: 1, prix_unitaire_ht: 10, taux_tva: 20)

      expect do
        AvoirEmissionService.new(avoir: second_avoir, utilisateur: utilisateur).call
      end.to raise_error(AvoirEmissionService::EmissionImpossibleError) { |erreur|
        expect(erreur.details.join(" ")).to include("ne peut pas dépasser son montant TTC")
      }

      expect(second_avoir.reload.statut).to eq("brouillon")
    end

    it "T-CONFORMITE-KO : un avoir référençant une facture encore en brouillon est refusé à la construction (invariant modèle)" do
      facture_brouillon = create(:facture, organisation: organisation, client: client)

      expect do
        build(:avoir, organisation: organisation, client: client, facture: facture_brouillon).save!(validate: true)
      end.to raise_error(ActiveRecord::RecordInvalid, /doit être émise/)
    end
  end

  describe "numérotation" do
    it "T-NUMEROTATION : la séquence avoir est indépendante de la séquence facture, sans trou" do
      facture_1 = create(:facture, :emise, organisation: organisation, client: client)
      avoir_1 = create(:avoir, organisation: organisation, client: client, facture: facture_1)
      ajouter_ligne_avoir(avoir_1, quantite: 1, prix_unitaire_ht: 50, taux_tva: 20)

      # une facture émise ENTRE-TEMPS ne doit pas interférer avec la séquence avoir.
      create(:facture, :emise, organisation: organisation, client: client)

      facture_2 = create(:facture, :emise, organisation: organisation, client: client)
      avoir_2 = create(:avoir, organisation: organisation, client: client, facture: facture_2)
      ajouter_ligne_avoir(avoir_2, quantite: 1, prix_unitaire_ht: 30, taux_tva: 20)

      AvoirEmissionService.new(avoir: avoir_1, utilisateur: utilisateur).call
      AvoirEmissionService.new(avoir: avoir_2, utilisateur: utilisateur).call

      annee = Date.current.year
      expect(avoir_1.reload.numero).to eq("AV-#{annee}-0001")
      expect(avoir_2.reload.numero).to eq("AV-#{annee}-0002")
    end
  end
end
