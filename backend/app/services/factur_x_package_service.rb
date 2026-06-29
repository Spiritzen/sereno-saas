# frozen_string_literal: true

require "hexapdf"
require "tempfile"
require "stringio"
require "cgi"

class FacturXPackageService
  class PackagingImpossibleError < StandardError; end

  EMBEDDED_XML_FILENAME = "factur-x.xml"
  EMBEDDED_XML_MIME_TYPE = "text/xml"
  EMBEDDED_XML_DESCRIPTION = "Facture électronique Factur-X"

def initialize(pdf_bytes:, xml_string:, facture:, icc_profile_path: nil)
  @pdf_bytes = pdf_bytes
  @xml_string = xml_string
  @facture = facture
  @icc_profile_path = icc_profile_path
end

  def call
    verifier_entrees!
    emballer_pdf
  rescue PackagingImpossibleError
    raise
  rescue StandardError => e
    raise PackagingImpossibleError, "Packaging Factur-X impossible : #{e.message}"
  end

  private

  def verifier_entrees!
    if @pdf_bytes.nil? || @pdf_bytes.bytesize.zero?
      raise PackagingImpossibleError, "Le PDF source est vide"
    end

    if @xml_string.nil? || @xml_string.bytesize.zero?
      raise PackagingImpossibleError, "Le XML Factur-X est vide"
    end

    if @facture.blank?
      raise PackagingImpossibleError, "La facture est introuvable"
    end

    if @icc_profile_path.present? && !File.file?(@icc_profile_path)
  raise PackagingImpossibleError, "Le profil ICC est introuvable"
end
  end

  def emballer_pdf
    avec_pdf_source_temporaire do |chemin_pdf_source|
     document = HexaPDF::Document.open(chemin_pdf_source)
forcer_version_pdf_17(document)

file_spec = embarquer_xml(document)
configurer_catalogue_factur_x(document, file_spec)
ajouter_metadata_xmp(document)
ajouter_output_intent(document) if @icc_profile_path.present?

ecrire_pdf_package(document)
    end
  end

  def avec_pdf_source_temporaire
    fichier = Tempfile.new(["sereno-pdf-source", ".pdf"])
    fichier.binmode
    fichier.write(@pdf_bytes)
    fichier.flush

    yield fichier.path
  ensure
    fichier&.close!
  end
  
 def forcer_version_pdf_17(document)
  appliquer_version = lambda do
    document.version = "1.7"
    document.catalog.delete(:Version) if document.catalog.key?(:Version)
  end

  appliquer_version.call

  document.register_listener(:before_write) do
    appliquer_version.call
  end
end

  def embarquer_xml(document)
    file_spec = document.files.add(
      StringIO.new(@xml_string),
      name: EMBEDDED_XML_FILENAME,
      description: EMBEDDED_XML_DESCRIPTION,
      mime_type: EMBEDDED_XML_MIME_TYPE,
      embed: true
    )

    file_spec[:F] = EMBEDDED_XML_FILENAME
    file_spec[:UF] = EMBEDDED_XML_FILENAME
    file_spec[:AFRelationship] = :Alternative

    embedded_file = file_spec[:EF]&.[](:F)
    embedded_file[:Subtype] = :"text/xml" if embedded_file

    file_spec
  end

  def configurer_catalogue_factur_x(document, file_spec)
    document.catalog[:AF] = [file_spec]
    document.catalog[:PageMode] = :UseAttachments
  end
  
  def ajouter_metadata_xmp(document)
  metadata_stream = document.add(
    {
      Type: :Metadata,
      Subtype: :XML
    },
    stream: xmp_metadata
  )

  document.catalog[:Metadata] = metadata_stream
end

def xmp_metadata
  numero = @facture.respond_to?(:numero) ? @facture.numero : nil
  titre = numero.present? ? "Facture #{numero}" : "Facture Sereno"

  titre = CGI.escapeHTML(titre)

  <<~XML
    <?xpacket begin="﻿" id="W5M0MpCehiHzreSzNTczkc9d"?>
    <x:xmpmeta xmlns:x="adobe:ns:meta/">
      <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description rdf:about=""
          xmlns:pdfaid="http://www.aiim.org/pdfa/ns/id/"
          pdfaid:part="3"
          pdfaid:conformance="B" />

        <rdf:Description rdf:about=""
          xmlns:pdf="http://ns.adobe.com/pdf/1.3/"
          pdf:Producer="Sereno" />

        <rdf:Description rdf:about=""
          xmlns:xmp="http://ns.adobe.com/xap/1.0/"
          xmp:CreatorTool="Sereno" />

        <rdf:Description rdf:about=""
          xmlns:dc="http://purl.org/dc/elements/1.1/">
          <dc:title>
            <rdf:Alt>
              <rdf:li xml:lang="x-default">#{titre}</rdf:li>
            </rdf:Alt>
          </dc:title>
        </rdf:Description>

        <rdf:Description rdf:about=""
          xmlns:pdfaExtension="http://www.aiim.org/pdfa/ns/extension/"
          xmlns:pdfaSchema="http://www.aiim.org/pdfa/ns/schema#"
          xmlns:pdfaProperty="http://www.aiim.org/pdfa/ns/property#">
          <pdfaExtension:schemas>
            <rdf:Bag>
              <rdf:li rdf:parseType="Resource">
                <pdfaSchema:schema>Factur-X PDF/A Extension Schema</pdfaSchema:schema>
                <pdfaSchema:namespaceURI>urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#</pdfaSchema:namespaceURI>
                <pdfaSchema:prefix>fx</pdfaSchema:prefix>
                <pdfaSchema:property>
                  <rdf:Seq>
                    <rdf:li rdf:parseType="Resource">
                      <pdfaProperty:name>DocumentType</pdfaProperty:name>
                      <pdfaProperty:valueType>Text</pdfaProperty:valueType>
                      <pdfaProperty:category>external</pdfaProperty:category>
                      <pdfaProperty:description>Type of the embedded invoice document</pdfaProperty:description>
                    </rdf:li>
                    <rdf:li rdf:parseType="Resource">
                      <pdfaProperty:name>DocumentFileName</pdfaProperty:name>
                      <pdfaProperty:valueType>Text</pdfaProperty:valueType>
                      <pdfaProperty:category>external</pdfaProperty:category>
                      <pdfaProperty:description>Name of the embedded XML invoice file</pdfaProperty:description>
                    </rdf:li>
                    <rdf:li rdf:parseType="Resource">
                      <pdfaProperty:name>Version</pdfaProperty:name>
                      <pdfaProperty:valueType>Text</pdfaProperty:valueType>
                      <pdfaProperty:category>external</pdfaProperty:category>
                      <pdfaProperty:description>Version of the Factur-X standard</pdfaProperty:description>
                    </rdf:li>
                    <rdf:li rdf:parseType="Resource">
                      <pdfaProperty:name>ConformanceLevel</pdfaProperty:name>
                      <pdfaProperty:valueType>Text</pdfaProperty:valueType>
                      <pdfaProperty:category>external</pdfaProperty:category>
                      <pdfaProperty:description>Conformance level of the embedded Factur-X XML document</pdfaProperty:description>
                    </rdf:li>
                  </rdf:Seq>
                </pdfaSchema:property>
              </rdf:li>
            </rdf:Bag>
          </pdfaExtension:schemas>
        </rdf:Description>

        <rdf:Description rdf:about=""
          xmlns:fx="urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#">
          <fx:DocumentType>INVOICE</fx:DocumentType>
          <fx:DocumentFileName>factur-x.xml</fx:DocumentFileName>
          <fx:Version>1.0</fx:Version>
          <fx:ConformanceLevel>EN 16931</fx:ConformanceLevel>
        </rdf:Description>
      </rdf:RDF>
    </x:xmpmeta>
    <?xpacket end="w"?>
  XML
end

  def ajouter_output_intent(document)
  icc_stream = document.add(
    {
      N: 3,
      Alternate: :DeviceRGB
    },
    stream: File.binread(@icc_profile_path)
  )

  output_intent = document.add(
    {
      Type: :OutputIntent,
      S: :GTS_PDFA1,
      OutputConditionIdentifier: "sRGB IEC61966-2.1",
      Info: "sRGB IEC61966-2.1",
      DestOutputProfile: icc_stream
    }
  )

  document.catalog[:OutputIntents] = [output_intent]
end

  def ecrire_pdf_package(document)
    fichier = Tempfile.new(["sereno-facturx-package", ".pdf"])
    fichier.binmode
    chemin = fichier.path
    fichier.close

    document.write(chemin)

    File.binread(chemin)
  ensure
    fichier&.close!
  end
end