# frozen_string_literal: true

require "hexapdf"
require "fileutils"

class FacturePdfService
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

    def initialize(facture:, font_path: nil, font_bold_path: nil)
    @facture = facture
    @organisation = facture.organisation
    @client = facture.client
    @lignes = facture.lignes_facture.order(:position)
    @devise = facture.devise.presence || "EUR"
    @font_path = font_path.presence || chemin_police_par_defaut!
    @font_bold_path = font_bold_path.presence || chemin_police_gras_par_defaut || @font_path
  end

    def call
    verifier_facture_generable!

    FileUtils.mkdir_p(dossier_facture)

    document = HexaPDF::Document.new
    nouvelle_page(document)

    dessiner_entete
    dessiner_infos_facture
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

  def verifier_facture_generable!
    raise PdfGenerationImpossibleError, "La facture est introuvable" if @facture.blank?
    raise PdfGenerationImpossibleError, "La facture doit être émise" unless @facture.statut == "emise"
    raise PdfGenerationImpossibleError, "La facture doit avoir un numéro" if @facture.numero.blank?
    raise PdfGenerationImpossibleError, "La facture doit avoir une date d'émission" if @facture.date_emission.blank?
    raise PdfGenerationImpossibleError, "La facture doit avoir un client" if @client.blank?
    raise PdfGenerationImpossibleError, "La facture doit avoir au moins une ligne" if @lignes.empty?
  end

    def nouvelle_page(document)
    @document = document
    @page = @document.pages.add
    @canvas = @page.canvas
    charger_polices!
    @y = MARGIN_TOP
  end

  def dessiner_entete
    ecrire_titre_principal("FACTURE")

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

  def dessiner_infos_facture
    ecrire_section("Informations facture")

    ecrire_ligne("Numéro : #{@facture.numero}", size: 10)
    ecrire_ligne("Date d'émission : #{format_date_fr(@facture.date_emission)}", size: 10)

    if @facture.date_echeance.present?
      ecrire_ligne("Date d'échéance : #{format_date_fr(@facture.date_echeance)}", size: 10)
    end

    ecrire_ligne("Devise : #{@devise}", size: 10)

    if @facture.conditions_paiement.present?
      ecrire_ligne("Conditions : #{@facture.conditions_paiement}", size: 10)
    end

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
    verifier_espace_disponible(100)

    ecrire_section("Totaux")

    ligne_total("Total HT", @facture.total_ht)
    ligne_total("Total TVA", @facture.total_tva)
    ligne_total("Total TTC", @facture.total_ttc, bold: true)

    if @facture.montant_paye.to_d.positive?
      ligne_total("Déjà payé", @facture.montant_paye)
      ligne_total("Reste à payer", montant_restant_a_payer, bold: true)
    end

    saut(16)
  end

  def dessiner_mentions
    mentions = []
    mentions << @facture.mentions if @facture.mentions.present?
    mentions << @organisation.mentions_legales if @organisation.mentions_legales.present?
    mentions << "TVA non applicable, art. 293 B du CGI" if @facture.total_tva.to_d.zero?
    mentions << "Facture électronique générée par Sereno."

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
      "Facture électronique PDF/A-3 avec XML Factur-X embarqué.",
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

  def dossier_facture
    Rails.root.join("storage", "factures", @facture.id)
  end

  def nom_fichier
    "facture-#{nom_fichier_securise(@facture.numero)}.pdf"
  end

  def chemin_fichier
    dossier_facture.join(nom_fichier)
  end

  def chemin_relatif
    "storage/factures/#{@facture.id}/#{nom_fichier}"
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

  def montant_restant_a_payer
    @facture.total_ttc.to_d - @facture.montant_paye.to_d
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
