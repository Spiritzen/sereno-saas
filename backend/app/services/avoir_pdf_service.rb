# frozen_string_literal: true

require "hexapdf"
require "fileutils"

# Voie (b) : miroir de FacturePdfService (SENSIBLE, non modifié — cf.
# SOCLE_GELE.md). Avoir n'a pas les colonnes date_echeance/
# conditions_paiement/montant_paye qu'utilise FacturePdfService : dupliquer
# est plus honnête que d'ajouter de faux champs de compatibilité sur Avoir
# pour un service pensé pour Facture. Structure simplifiée en conséquence
# (pas de section échéance/paiement, sans objet pour une note de crédit).
class AvoirPdfService
  class PdfGenerationImpossibleError < StandardError; end

  attr_reader :chemin_archive, :chemin_archive_relatif

  PAGE_WIDTH = 595
  PAGE_HEIGHT = 842

  MARGIN_LEFT = 50
  MARGIN_RIGHT = 50
  MARGIN_TOP = 800
  MARGIN_BOTTOM = 60

  TABLE_X_DESIGNATION = 50
  TABLE_X_QUANTITE = 300
  TABLE_X_PRIX = 355
  TABLE_X_TVA = 425
  TABLE_X_TOTAL = 485

  DEFAULT_FONT_PATHS = [
    ENV["FACTURX_FONT_PATH"],
    Rails.root.join("config", "facturx", "fonts", "Sereno-Regular.ttf").to_s,
    "C:/Windows/Fonts/arial.ttf",
    "C:/Windows/Fonts/calibri.ttf",
    "C:/Windows/Fonts/segoeui.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf"
  ].compact.freeze

  DEFAULT_BOLD_FONT_PATHS = [
    ENV["FACTURX_FONT_BOLD_PATH"],
    Rails.root.join("config", "facturx", "fonts", "Sereno-Bold.ttf").to_s,
    "C:/Windows/Fonts/arialbd.ttf",
    "C:/Windows/Fonts/calibrib.ttf",
    "C:/Windows/Fonts/segoeuib.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
  ].compact.freeze

  def initialize(avoir:, font_path: nil, font_bold_path: nil)
    @avoir = avoir
    @organisation = avoir.organisation
    @client = avoir.client
    @facture = avoir.facture
    @lignes = avoir.lignes_avoir.order(:position)
    @devise = @facture&.devise.presence || "EUR"
    @font_path = font_path.presence || chemin_police_par_defaut!
    @font_bold_path = font_bold_path.presence || chemin_police_gras_par_defaut || @font_path
  end

  def call
    verifier_avoir_generable!

    FileUtils.mkdir_p(dossier_avoir)

    document = HexaPDF::Document.new
    nouvelle_page(document)

    dessiner_entete
    dessiner_infos_avoir
    dessiner_client
    dessiner_lignes
    dessiner_totaux
    dessiner_mentions
    dessiner_pied_de_page

    @chemin_archive = chemin_fichier
    @chemin_archive_relatif = chemin_relatif

    document.write(@chemin_archive.to_s)

    @chemin_archive
  end

  private

  def verifier_avoir_generable!
    raise PdfGenerationImpossibleError, "L'avoir est introuvable" if @avoir.blank?
    raise PdfGenerationImpossibleError, "L'avoir doit être émis" unless @avoir.statut == "emise"
    raise PdfGenerationImpossibleError, "L'avoir doit avoir un numéro" if @avoir.numero.blank?
    raise PdfGenerationImpossibleError, "L'avoir doit avoir une date d'émission" if @avoir.date_emission.blank?
    raise PdfGenerationImpossibleError, "L'avoir doit avoir un client" if @client.blank?
    raise PdfGenerationImpossibleError, "L'avoir doit référencer une facture" if @facture.blank?
    raise PdfGenerationImpossibleError, "L'avoir doit avoir au moins une ligne" if @lignes.empty?
  end

  def nouvelle_page(document)
    @document = document
    @page = @document.pages.add
    @canvas = @page.canvas
    charger_polices!
    dessiner_filigrane
    @y = MARGIN_TOP
  end

  # V1.2b-bis — distinction visuelle avoir/facture au premier coup d'œil.
  # Dessiné dans le PDF de BASE (ce service, SENSIBLE), AVANT l'enveloppe
  # PDF/A-3 (FacturXPackageService, GELÉ, non touché) : l'enveloppe embarque
  # le XML et pose l'OutputIntent/XMP par-dessus un PDF déjà complet, elle ne
  # regarde jamais le contenu des pages. Couleur UNIE (DeviceGray, pas de
  # transparence/ExtGState) : compatible sans ambiguïté avec PDF/A-3B, et
  # plus simple à raisonner qu'une opacité — un simple gris clair qui ne
  # masque jamais le texte réel dessiné par-dessus ensuite.
  # save_graphics_state(&block) restaure automatiquement couleur/police/CTM
  # après le bloc (cf. HexaPDF::Content::Canvas) : aucune fuite d'état vers
  # le reste du contenu de la page.
  def dessiner_filigrane
    @canvas.save_graphics_state do
      @canvas.fill_color(210)
      @canvas.font(@font_bold, size: 92)
      @canvas.rotate(45, origin: [ PAGE_WIDTH / 2.0, PAGE_HEIGHT / 2.0 ]) do
        @canvas.text("AVOIR", at: [ PAGE_WIDTH / 2.0 - 175, PAGE_HEIGHT / 2.0 - 30 ])
      end
    end
  end

  def dessiner_entete
    ecrire_titre_principal("AVOIR")

    ecrire_ligne(@organisation.raison_sociale, size: 12, bold: true)
    ecrire_ligne(adresse_complete(@organisation), size: 9)
    ecrire_ligne("SIRET : #{@organisation.siret}", size: 9)

    if valeur(@organisation, :numero_tva).present?
      ecrire_ligne("TVA : #{@organisation.numero_tva}", size: 9)
    end

    saut(14)
    ligne_horizontale
    saut(16)
  end

  def dessiner_infos_avoir
    ecrire_section("Informations avoir")

    ecrire_ligne("Numéro : #{@avoir.numero}", size: 10)
    ecrire_ligne("Date d'émission : #{format_date_fr(@avoir.date_emission)}", size: 10)
    ecrire_ligne("Motif : #{@avoir.motif}", size: 10)
    ecrire_ligne("Facture corrigée : #{@facture.numero}", size: 10)
    ecrire_ligne("Devise : #{@devise}", size: 10)

    saut(12)
  end

  def dessiner_client
    ecrire_section("Client")

    ecrire_ligne(@client.raison_sociale, size: 11, bold: true)
    ecrire_ligne(adresse_complete(@client), size: 9)

    if valeur(@client, :siret).present?
      ecrire_ligne("SIRET : #{@client.siret}", size: 9)
    end

    if valeur(@client, :numero_tva).present?
      ecrire_ligne("TVA : #{@client.numero_tva}", size: 9)
    end

    saut(14)
  end

  def dessiner_lignes
    ecrire_section("Détail")

    verifier_espace_disponible(60)

    ecrire_texte("Désignation", TABLE_X_DESIGNATION, @y, size: 9, bold: true)
    ecrire_texte("Qté", TABLE_X_QUANTITE, @y, size: 9, bold: true)
    ecrire_texte("PU HT", TABLE_X_PRIX, @y, size: 9, bold: true)
    ecrire_texte("TVA", TABLE_X_TVA, @y, size: 9, bold: true)
    ecrire_texte("Total HT", TABLE_X_TOTAL, @y, size: 9, bold: true)

    saut(12)
    ligne_horizontale
    saut(12)

    @lignes.each do |ligne|
      verifier_espace_disponible(35)

      ecrire_texte(texte_court(ligne.designation, 34), TABLE_X_DESIGNATION, @y, size: 9)
      ecrire_texte(format_quantite(ligne.quantite), TABLE_X_QUANTITE, @y, size: 9)
      ecrire_texte(format_monnaie(ligne.prix_unitaire_ht), TABLE_X_PRIX, @y, size: 9)
      ecrire_texte("#{format_montant(ligne.taux_tva)} %", TABLE_X_TVA, @y, size: 9)
      ecrire_texte(format_monnaie(ligne.total_ht), TABLE_X_TOTAL, @y, size: 9)

      saut(18)
    end

    saut(4)
    ligne_horizontale
    saut(18)
  end

  def dessiner_totaux
    verifier_espace_disponible(80)

    ecrire_section("Totaux")

    ligne_total("Total HT", @avoir.total_ht)
    ligne_total("Total TVA", @avoir.total_tva)
    ligne_total("Total TTC", @avoir.total_ttc, bold: true)

    saut(16)
  end

  def dessiner_mentions
    mentions = []
    mentions << @organisation.mentions_legales if @organisation.mentions_legales.present?
    mentions << "TVA non applicable, art. 293 B du CGI" if @avoir.total_tva.to_d.zero?
    mentions << "Avoir électronique généré par Sereno, en référence à la facture #{@facture.numero}."

    mentions = mentions.compact_blank.uniq

    return if mentions.empty?

    verifier_espace_disponible(80)

    ecrire_section("Mentions")

    mentions.each do |mention|
      ecrire_multiligne(mention, size: 9, max_length: 95)
      saut(4)
    end
  end

  def dessiner_pied_de_page
    ecrire_texte(
      "Avoir électronique PDF/A-3 avec XML Factur-X embarqué.",
      MARGIN_LEFT,
      35,
      size: 8
    )
  end

  def ligne_total(label, montant, bold: false)
    ecrire_texte(label, 355, @y, size: 10, bold: bold)
    ecrire_texte(format_monnaie(montant), 455, @y, size: 10, bold: bold)
    saut(15)
  end

  def ecrire_titre_principal(contenu)
    verifier_espace_disponible(50)

    ecrire_texte(contenu, MARGIN_LEFT, @y, size: 24, bold: true)
    saut(36)
  end

  def ecrire_section(contenu)
    verifier_espace_disponible(40)

    ecrire_texte(contenu, MARGIN_LEFT, @y, size: 14, bold: true)
    saut(22)
  end

  def ecrire_ligne(contenu, size: 10, bold: false, x: MARGIN_LEFT)
    verifier_espace_disponible(20)

    ecrire_texte(contenu.to_s, x, @y, size: size, bold: bold)
    saut(size + 5)
  end

  def ecrire_multiligne(contenu, size: 10, max_length: 85)
    decouper_texte(contenu.to_s, max_length).each do |ligne|
      ecrire_ligne(ligne, size: size)
    end
  end

  def ecrire_texte(contenu, x, y, size: 10, bold: false)
    police = bold ? @font_bold : @font_regular

    @canvas.font(police, size: size)
    @canvas.text(contenu.to_s, at: [ x, y ])
  end

  def ligne_horizontale
    @canvas.line(MARGIN_LEFT, @y, PAGE_WIDTH - MARGIN_RIGHT, @y).stroke
  end

  def saut(nombre)
    @y -= nombre
  end

  def verifier_espace_disponible(hauteur_necessaire = 30)
    return if @y - hauteur_necessaire > MARGIN_BOTTOM

    nouvelle_page(@document)
  end

  def decouper_texte(texte, max_length)
    texte.scan(/.{1,#{max_length}}(?:\s+|$)/).map(&:strip).reject(&:blank?)
  end

  def texte_court(contenu, max_length)
    texte = contenu.to_s

    return texte if texte.length <= max_length

    "#{texte[0...max_length]}..."
  end

  def charger_polices!
    return if @font_regular.present? && @font_bold.present?

    @font_regular = @document.fonts.add(@font_path)
    @font_bold = @document.fonts.add(@font_bold_path)
  end

  def chemin_police_par_defaut!
    chemin = DEFAULT_FONT_PATHS.find { |path| path.present? && File.file?(path) }

    return chemin if chemin.present?

    raise PdfGenerationImpossibleError,
          "Aucune police TTF trouvée. Renseigner FACTURX_FONT_PATH."
  end

  def chemin_police_gras_par_defaut
    DEFAULT_BOLD_FONT_PATHS.find { |path| path.present? && File.file?(path) }
  end

  # Cloisonné par Rails.env (storage/<env>/avoirs/...), même principe que
  # FacturePdfService/FacturXStorageService.
  def dossier_avoir
    Rails.root.join("storage", Rails.env, "avoirs", @avoir.id)
  end

  def nom_fichier
    "avoir-#{nom_fichier_securise(@avoir.numero)}.pdf"
  end

  def chemin_fichier
    dossier_avoir.join(nom_fichier)
  end

  def chemin_relatif
    "storage/#{Rails.env}/avoirs/#{@avoir.id}/#{nom_fichier}"
  end

  def nom_fichier_securise(valeur)
    valeur.to_s.gsub(/[^0-9A-Za-z.\-]/, "_")
  end

  def adresse_complete(tiers)
    [
      valeur(tiers, :adresse_ligne1),
      valeur(tiers, :adresse_ligne2),
      "#{valeur(tiers, :code_postal)} #{valeur(tiers, :ville)}".strip,
      valeur(tiers, :pays).presence || "FR"
    ].compact_blank.join(" — ")
  end

  def format_date_fr(date)
    date.strftime("%d/%m/%Y")
  end

  def format_monnaie(valeur)
    "#{format_montant(valeur)} #{@devise}"
  end

  def format_montant(valeur)
    format("%.2f", BigDecimal(valeur.to_s))
  end

  def format_quantite(valeur)
    format("%.2f", BigDecimal(valeur.to_s))
  end

  def valeur(objet, attribut)
    return "" if objet.blank?
    return "" unless objet.respond_to?(attribut)

    objet.public_send(attribut).to_s
  end
end
