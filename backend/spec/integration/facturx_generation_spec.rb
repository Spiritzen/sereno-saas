# frozen_string_literal: true

require "rails_helper"
require "hexapdf"
require "nokogiri"
require "tempfile"
require "fileutils"
require "bigdecimal"
require "active_support/testing/time_helpers"

# Garde-fou interne (Sprint 1A) : prouve que l'artefact Factur-X généré est
# structurellement cohérent, SANS dépendre d'outils externes (veraPDF/xmllint/
# Schematron — voir Sprint 1B pour la certification officielle PDF/A-3 / XSD /
# EN16931).
RSpec.describe "Génération Factur-X — garde-fou interne", type: :integration do
  include ActiveSupport::Testing::TimeHelpers

  DATE_EMISSION_FIGEE = Date.new(2026, 1, 15)

  def extraire_xml_embarque(pdf_bytes)
    fichier = Tempfile.new([ "sereno-facturx-roundtrip", ".pdf" ])
    fichier.binmode
    fichier.write(pdf_bytes)
    fichier.flush

    document = HexaPDF::Document.open(fichier.path)
    file_spec = document.catalog[:AF]&.first

    raise "Aucun fichier /AF trouvé dans le PDF" if file_spec.nil?
    raise "Le fichier embarqué n'est pas nommé factur-x.xml" unless file_spec[:F] == "factur-x.xml"

    file_spec[:EF][:F].stream
  ensure
    fichier&.close!
  end

  describe "chemin heureux — facture conforme" do
    around do |example|
      travel_to(DATE_EMISSION_FIGEE) { example.run }
    end

    let(:organisation) { create(:organisation) }
    let(:client) { create(:client, organisation: organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation) }
    let(:facture) { create(:facture, :avec_ligne, organisation: organisation, client: client) }

    after do
      FileUtils.rm_rf(Rails.root.join("storage", "factures", facture.id.to_s))
    end

    it "produit un XML et un PDF non vides, avec pdf_url/xml_url renseignés" do
      facture_emise = FactureEmissionService.new(facture: facture, utilisateur: utilisateur).call
      facture_emise.reload

      expect(facture_emise.pdf_url).to be_present
      expect(facture_emise.xml_url).to be_present
      expect(File.size(Rails.root.join(facture_emise.pdf_url))).to be > 0
      expect(File.size(Rails.root.join(facture_emise.xml_url))).to be > 0
    end

    it "génère un XML CII conforme (profil EN16931, TypeCode 380, lignes, totaux)" do
      facture_emise = FactureEmissionService.new(facture: facture, utilisateur: utilisateur).call
      xml_disque = File.read(Rails.root.join(facture_emise.xml_url))
      doc = Nokogiri::XML(xml_disque) { |config| config.strict }
      doc.remove_namespaces!

      expect(xml_disque).to include("CrossIndustryInvoice")
      expect(doc.at_xpath("//GuidelineSpecifiedDocumentContextParameter/ID")&.text).to eq("urn:cen.eu:en16931:2017")
      expect(doc.at_xpath("//ExchangedDocument/TypeCode")&.text).to eq("380")
      expect(doc.xpath("//IncludedSupplyChainTradeLineItem").size).to be >= 1
      expect(doc.at_xpath("//SpecifiedTradeSettlementHeaderMonetarySummation/GrandTotalAmount")).to be_present
      expect(doc.at_xpath("//SpecifiedTradeSettlementHeaderMonetarySummation/TaxTotalAmount")).to be_present
    end

    it "SellerTradeParty : GlobalID (SIRET) et SpecifiedLegalOrganization/ID (SIREN) conformes France CTC (BR-FR-09/BR-FR-10)" do
      facture_emise = FactureEmissionService.new(facture: facture, utilisateur: utilisateur).call

      doc = Nokogiri::XML(File.read(Rails.root.join(facture_emise.xml_url)))
      doc.remove_namespaces!

      vendeur = doc.at_xpath("//SellerTradeParty")
      global_id = vendeur.at_xpath("GlobalID")
      siren = vendeur.at_xpath("SpecifiedLegalOrganization/ID")

      expect(global_id).to be_present
      expect(global_id.text).to eq(organisation.siret)
      expect(global_id["schemeID"]).to eq("0009")

      expect(siren).to be_present
      expect(siren.text).to match(/\A\d{9}\z/)
      expect(siren["schemeID"]).to eq("0002")
      expect(siren.text).to eq(organisation.siret.first(9))

      enfants_ordonnes = vendeur.elements.map(&:name)
      expect(enfants_ordonnes.index("GlobalID")).to be < enfants_ordonnes.index("Name")
    end

    it "round-trip : le XML embarqué dans le PDF/A-3 est non vide, parseable, et identique au XML de référence sur disque" do
      facture_emise = FactureEmissionService.new(facture: facture, utilisateur: utilisateur).call

      xml_disque = File.binread(Rails.root.join(facture_emise.xml_url))
      pdf_bytes = File.binread(Rails.root.join(facture_emise.pdf_url))
      xml_embarque = extraire_xml_embarque(pdf_bytes)

      expect(xml_embarque.bytesize).to be > 0
      expect { Nokogiri::XML(xml_embarque) { |config| config.strict } }.not_to raise_error
      expect(xml_embarque).to eq(xml_disque)
    end

    it "cohérence PDF/XML au centime (BR-CO) : GrandTotal/TaxTotal/lignes correspondent à la base et à l'exemple canonique 2x100 HT / TVA 20% / TTC 240" do
      facture_emise = FactureEmissionService.new(facture: facture, utilisateur: utilisateur).call
      facture_emise.reload

      doc = Nokogiri::XML(File.read(Rails.root.join(facture_emise.xml_url)))
      doc.remove_namespaces!

      grand_total = BigDecimal(doc.at_xpath("//SpecifiedTradeSettlementHeaderMonetarySummation/GrandTotalAmount").text)
      tax_total = BigDecimal(doc.at_xpath("//SpecifiedTradeSettlementHeaderMonetarySummation/TaxTotalAmount").text)
      lignes_total_ht = doc.xpath("//IncludedSupplyChainTradeLineItem//LineTotalAmount").sum { |noeud| BigDecimal(noeud.text) }

      expect(grand_total).to eq(BigDecimal(facture_emise.total_ttc.to_s).round(2))
      expect(tax_total).to eq(BigDecimal(facture_emise.total_tva.to_s).round(2))
      expect(lignes_total_ht).to eq(BigDecimal(facture_emise.total_ht.to_s).round(2))

      expect(facture_emise.total_ht).to eq(BigDecimal("200.00"))
      expect(facture_emise.total_tva).to eq(BigDecimal("40.00"))
      expect(facture_emise.total_ttc).to eq(BigDecimal("240.00"))
    end

    it "valide contre le XSD officiel Factur-X 1.09 EN16931 vendoré (Sprint 1C-E)" do
      facture_emise = FactureEmissionService.new(facture: facture, utilisateur: utilisateur).call

      xsd_path = Rails.root.join("vendor", "facturx", "xsd", "en16931", "Factur-X_1.09_EN16931.xsd")
      schema = Nokogiri::XML::Schema.new(File.open(xsd_path))
      document = Nokogiri::XML(File.read(Rails.root.join(facture_emise.xml_url)))

      erreurs = schema.validate(document)

      expect(erreurs.map(&:message)).to eq([])
    end

    it "SellerTradeParty : SpecifiedLegalOrganization apparaît avant DefinedTradeContact (ordre XSD TradePartyType)" do
      facture_emise = FactureEmissionService.new(facture: facture, utilisateur: utilisateur).call

      doc = Nokogiri::XML(File.read(Rails.root.join(facture_emise.xml_url)))
      doc.remove_namespaces!

      vendeur = doc.at_xpath("//SellerTradeParty")
      enfants_ordonnes = vendeur.elements.map(&:name)

      index_legal_organization = enfants_ordonnes.index("SpecifiedLegalOrganization")
      index_contact = enfants_ordonnes.index("DefinedTradeContact")

      expect(index_legal_organization).not_to be_nil
      expect(index_contact).not_to be_nil
      expect(index_legal_organization).to be < index_contact
    end
  end

  describe "chemin refusé — facture non conforme" do
    it "refuse l'émission d'une facture sans ligne et ne produit aucun artefact" do
      facture = create(:facture)
      utilisateur = create(:utilisateur, organisation: facture.organisation)

      expect do
        FactureEmissionService.new(facture: facture, utilisateur: utilisateur).call
      end.to raise_error(FactureEmissionService::EmissionImpossibleError) { |erreur|
        expect(erreur.details.join(" ")).to include("La facture doit contenir au moins une ligne")
      }

      facture.reload
      expect(facture.statut).to eq("brouillon")
      expect(facture.numero).to be_nil
      expect(facture.pdf_url).to be_nil
      expect(facture.xml_url).to be_nil
      expect(Dir.exist?(Rails.root.join("storage", "factures", facture.id.to_s))).to be(false)
    end
  end
end
