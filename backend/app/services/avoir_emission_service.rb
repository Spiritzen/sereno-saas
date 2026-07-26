# frozen_string_literal: true

require "fileutils"

# Voie (b) : miroir de FactureEmissionService (GELÉ STRICT, lu en lecture
# seule, jamais modifié). Orchestration en UNE transaction : conformité ->
# numérotation -> génération XML/PDF -> assemblage PDF/A-3 -> statut.
#
# RÉUTILISATION SANS MODIFICATION (§2.C du prompt — "appeler un service gelé
# est autorisé, le modifier ne l'est pas") :
#   - FacturXStorageService : sa signature (facture:, xml_string:) et son
#     corps ne lisent que .blank?, .statut, .numero, .id — tous présents et
#     de même sémantique sur Avoir (le statut "emise" existe dans les deux
#     STATUTS). Appelé tel quel avec facture: @avoir. Quirk cosmétique
#     accepté : le chemin de stockage reste "storage/factures/<avoir_id>/…"
#     (dossier nommé en dur dans le service gelé/sensible) — sans risque de
#     collision (avoir.id et facture.id sont des UUID d'espaces disjoints),
#     juste un nom de dossier trompeur pour l'inspection manuelle.
#   - FacturXPackageService : sa signature (pdf_bytes:, xml_string:, facture:,
#     icc_profile_path:) ne lit que .blank? et .respond_to?(:numero) sur
#     facture: — déjà entièrement générique. Appelé tel quel avec facture: @avoir.
#
# AvoirXmlService et AvoirPdfService sont NEUFS (voie b) : voir leurs
# propres commentaires pour la justification de la duplication.
class AvoirEmissionService
  class EmissionImpossibleError < StandardError
    attr_reader :details

    def initialize(message = "Émission impossible", details: [])
      @details = Array(details)
      @details = [ message ] if @details.empty?

      super(message)
    end
  end

  def initialize(avoir:, utilisateur:)
    @avoir = avoir
    @utilisateur = utilisateur
    @organisation = avoir.organisation
    @chemins_archives_generes = []
  end

  def call
    ActiveRecord::Base.transaction do
      @avoir.lock!

      recalculer_totaux_si_possible!
      verifier_conformite!

      numero = generer_numero!

      @avoir.assign_attributes(
        numero: numero,
        statut: "emise",
        date_emission: Date.current,
        emis_at: Time.current
      )

      generer_archives_factur_x!

      @avoir.save!

      # Pas d'événement créé ici : le journal miroir evenement_avoir est
      # V1.2b (cf. prompt §0 — "décidé en V1.2b"). EvenementFacture ne peut
      # pas l'accueillir : facture_id y est une FK obligatoire non
      # polymorphique (cf. reco socle gelé §5/§6).

      @avoir
    end
  rescue StandardError
    nettoyer_archives_generees
    raise
  end

  private

  def recalculer_totaux_si_possible!
    return unless @avoir.respond_to?(:recalculer_totaux!)

    @avoir.recalculer_totaux!
    @avoir.reload
  end

  def verifier_conformite!
    resultat = AvoirConformiteService.new(avoir: @avoir).call

    return if resultat.conforme?

    raise EmissionImpossibleError.new(
      "L'avoir n'est pas conforme",
      details: resultat.erreurs
    )
  end

  def generer_numero!
    NumerotationService.new(
      organisation: @organisation,
      type_document: "avoir",
      date: Date.current
    ).generer!
  end

  def generer_archives_factur_x!
    xml_string = AvoirXmlService.new(avoir: @avoir).call

    xml_service = FacturXStorageService.new(
      facture: @avoir,
      xml_string: xml_string
    )

    chemin_xml = xml_service.call
    @chemins_archives_generes << chemin_xml

    pdf_service = AvoirPdfService.new(avoir: @avoir)
    chemin_pdf = pdf_service.call
    @chemins_archives_generes << chemin_pdf

    pdf_visuel_bytes = File.binread(chemin_pdf.to_s)

    pdf_a3_bytes = FacturXPackageService.new(
      pdf_bytes: pdf_visuel_bytes,
      xml_string: xml_string,
      facture: @avoir,
      icc_profile_path: chemin_profil_icc!
    ).call

    File.binwrite(chemin_pdf.to_s, pdf_a3_bytes)

    @avoir.assign_attributes(
      xml_url: xml_service.chemin_archive_relatif,
      pdf_url: pdf_service.chemin_archive_relatif
    )
  rescue AvoirXmlService::GenerationImpossibleError,
         FacturXStorageService::StorageImpossibleError,
         AvoirPdfService::PdfGenerationImpossibleError,
         FacturXPackageService::PackagingImpossibleError,
         SystemCallError => e
    raise EmissionImpossibleError.new(
      "Archivage Factur-X impossible",
      details: [ e.message ]
    )
  end

  # Dupliqué depuis FactureEmissionService#chemin_profil_icc! (privée,
  # gelée, non appelable depuis l'extérieur) : simple résolution de chemin
  # d'environnement, aucune logique de conformité propre à ce fichier.
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
end
