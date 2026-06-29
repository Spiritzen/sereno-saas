# frozen_string_literal: true

require "fileutils"

class FactureEmissionService
  class EmissionImpossibleError < StandardError
    attr_reader :details

    def initialize(message = "Émission impossible", details: [])
      @details = Array(details)
      @details = [ message ] if @details.empty?

      super(message)
    end
  end

  def initialize(facture:, utilisateur:)
    @facture = facture
    @utilisateur = utilisateur
    @organisation = facture.organisation
    @chemins_archives_generes = []
  end

  def call
    ActiveRecord::Base.transaction do
      @facture.lock!

      recalculer_totaux_si_possible!
      verifier_conformite!

      numero = generer_numero!

      @facture.assign_attributes(
        numero: numero,
        statut: "emise",
        date_emission: Date.current,
        emise_at: Time.current
      )

      generer_archives_factur_x!

      @facture.save!

      creer_evenement_emission!

      @facture
    end
  rescue StandardError
    nettoyer_archives_generees
    raise
  end

  private

  def recalculer_totaux_si_possible!
    return unless @facture.respond_to?(:recalculer_totaux!)

    @facture.recalculer_totaux!
    @facture.reload
  end

  def verifier_conformite!
    resultat = FactureConformiteService.new(facture: @facture).call

    return if resultat.conforme?

    raise EmissionImpossibleError.new(
      "La facture n'est pas conforme",
      details: resultat.erreurs
    )
  end

  def generer_numero!
    NumerotationService.new(
      organisation: @organisation,
      type_document: @facture.type_document,
      date: Date.current
    ).generer!
  end

    def generer_archives_factur_x!
    xml_string = FacturXXmlService.new(facture: @facture).call

    xml_service = FacturXStorageService.new(
      facture: @facture,
      xml_string: xml_string
    )

    chemin_xml = xml_service.call
    @chemins_archives_generes << chemin_xml

    pdf_service = FacturePdfService.new(facture: @facture)
    chemin_pdf = pdf_service.call
    @chemins_archives_generes << chemin_pdf

    pdf_visuel_bytes = File.binread(chemin_pdf.to_s)

    pdf_a3_bytes = FacturXPackageService.new(
      pdf_bytes: pdf_visuel_bytes,
      xml_string: xml_string,
      facture: @facture,
      icc_profile_path: chemin_profil_icc!
    ).call

    File.binwrite(chemin_pdf.to_s, pdf_a3_bytes)

    @facture.assign_attributes(
      xml_url: xml_service.chemin_archive_relatif,
      pdf_url: pdf_service.chemin_archive_relatif
    )
  rescue FacturXXmlService::GenerationImpossibleError,
         FacturXStorageService::StorageImpossibleError,
         FacturePdfService::PdfGenerationImpossibleError,
         FacturXPackageService::PackagingImpossibleError,
         SystemCallError => e
    raise EmissionImpossibleError.new(
      "Archivage Factur-X impossible",
      details: [ e.message ]
    )
  end

    def chemin_profil_icc!
    chemins = [
      ENV["FACTURX_ICC_PROFILE_PATH"],
      Rails.root.join("config", "facturx", "sRGB.icc").to_s,
      "C:/Windows/System32/spool/drivers/color/sRGB Color Space Profile.icm",
      "C:/Windows/System32/spool/drivers/color/sRGB Color Space Profile.icc",
      "/usr/share/color/icc/sRGB.icc",
      "/usr/share/color/icc/colord/sRGB.icc",
      "/usr/share/color/icc/ghostscript/srgb.icc",
      "/System/Library/ColorSync/Profiles/sRGB Profile.icc"
    ].compact_blank

    chemin = chemins.find { |path| File.file?(path) }

    return chemin if chemin.present?

    raise FacturXPackageService::PackagingImpossibleError,
          "Aucun profil ICC sRGB trouvé. Renseigner FACTURX_ICC_PROFILE_PATH."
  end

  def nettoyer_archives_generees
    @chemins_archives_generes.each do |chemin|
      FileUtils.rm_f(chemin.to_s)
    end
  end

  def creer_evenement_emission!
    EvenementFacture.create!(
      organisation_id: @organisation.id,
      facture_id: @facture.id,
      utilisateur_id: @utilisateur.id,
      statut: @facture.statut,
      source: "interne",
      payload: {
        action: "emission_facture",
        numero: @facture.numero,
        date_emission: @facture.date_emission&.iso8601,
        emise_at: @facture.emise_at&.iso8601,
        pdf_url: @facture.pdf_url,
        xml_url: @facture.xml_url
      }
    )
  end
end
