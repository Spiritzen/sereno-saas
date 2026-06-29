# frozen_string_literal: true

require "rails_helper"
require "hexapdf"
require "tempfile"
require "nokogiri"

RSpec.describe FacturXPackageService do
  let(:facture) { instance_double(Facture, numero: "FAC-2026-0001") }

  let(:xml_string) do
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?><test>Sereno</test>"
  end

  def pdf_source_bytes
    document = HexaPDF::Document.new
    page = document.pages.add
    canvas = page.canvas
    canvas.font("Helvetica", size: 12)
    canvas.text("PDF source Sereno", at: [50, 750])

    fichier = Tempfile.new(["sereno-source", ".pdf"])
    fichier.binmode
    chemin = fichier.path
    fichier.close

    document.write(chemin)

    File.binread(chemin)
  ensure
    fichier&.close!
  end

  def ouvrir_pdf(bytes)
    fichier = Tempfile.new(["sereno-package", ".pdf"])
    fichier.binmode
    fichier.write(bytes)
    fichier.flush

    yield HexaPDF::Document.open(fichier.path)
  ensure
    fichier&.close!
  end

  it "embarque factur-x.xml dans le catalogue /AF du PDF" do
    pdf_package = described_class.new(
      pdf_bytes: pdf_source_bytes,
      xml_string: xml_string,
      facture: facture
    ).call

    ouvrir_pdf(pdf_package) do |document|
      af = document.catalog[:AF]

      expect(af).to be_present
      expect(af.size).to eq(1)

      file_spec = af.first

      expect(file_spec[:F]).to eq("factur-x.xml")
      expect(file_spec[:UF]).to eq("factur-x.xml")
      expect(file_spec[:AFRelationship]).to eq(:Alternative)
      expect(document.catalog[:PageMode]).to eq(:UseAttachments)
    end
  end

  it "embarque le XML avec le MIME type text/xml" do
    pdf_package = described_class.new(
      pdf_bytes: pdf_source_bytes,
      xml_string: xml_string,
      facture: facture
    ).call

    ouvrir_pdf(pdf_package) do |document|
      file_spec = document.catalog[:AF].first
      embedded_file = file_spec[:EF][:F]

      expect(embedded_file[:Subtype]).to eq(:"text/xml")
    end
  end

  it "permet d'extraire et parser le XML embarqué" do
    pdf_package = described_class.new(
      pdf_bytes: pdf_source_bytes,
      xml_string: xml_string,
      facture: facture
    ).call

    ouvrir_pdf(pdf_package) do |document|
      file_spec = document.catalog[:AF].first
      embedded_file = file_spec[:EF][:F]
      xml_extrait = embedded_file.stream

      expect(xml_extrait.bytesize).to be > 0
      expect(xml_extrait).to include("<test>Sereno</test>")

      expect do
        Nokogiri::XML(xml_extrait) { |config| config.strict }
      end.not_to raise_error
    end
  end
  
  it "ajoute les métadonnées XMP PDF/A-3 et Factur-X" do
  pdf_package = described_class.new(
    pdf_bytes: pdf_source_bytes,
    xml_string: xml_string,
    facture: facture
  ).call

  ouvrir_pdf(pdf_package) do |document|
    metadata = document.catalog[:Metadata]

    expect(metadata).to be_present
    expect(metadata[:Type]).to eq(:Metadata)
    expect(metadata[:Subtype]).to eq(:XML)

    xmp = metadata.stream

    expect(xmp).to include("<pdfaSchema:namespaceURI>urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#</pdfaSchema:namespaceURI>")
expect(xmp).to include("<pdfaSchema:prefix>fx</pdfaSchema:prefix>")
expect(xmp).to include("<pdfaProperty:name>DocumentType</pdfaProperty:name>")
expect(xmp).to include("<pdfaProperty:name>DocumentFileName</pdfaProperty:name>")
expect(xmp).to include("<pdfaProperty:name>Version</pdfaProperty:name>")
expect(xmp).to include("<pdfaProperty:name>ConformanceLevel</pdfaProperty:name>")
expect(xmp).to include("<fx:DocumentType>INVOICE</fx:DocumentType>")
expect(xmp).to include("<fx:DocumentFileName>factur-x.xml</fx:DocumentFileName>")
expect(xmp).to include("<fx:Version>1.0</fx:Version>")
expect(xmp).to include("<fx:ConformanceLevel>EN 16931</fx:ConformanceLevel>")
  end
end

  it "refuse un XML vide" do
    service = described_class.new(
      pdf_bytes: pdf_source_bytes,
      xml_string: "",
      facture: facture
    )

    expect { service.call }.to raise_error(
      FacturXPackageService::PackagingImpossibleError,
      "Le XML Factur-X est vide"
    )
  end

  it "refuse un PDF source vide" do
    service = described_class.new(
      pdf_bytes: "",
      xml_string: xml_string,
      facture: facture
    )

    expect { service.call }.to raise_error(
      FacturXPackageService::PackagingImpossibleError,
      "Le PDF source est vide"
    )
  end
end