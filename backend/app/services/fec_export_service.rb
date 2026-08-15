# frozen_string_literal: true

# Export FEC (MVP, 15/08/2026) — LECTURE SEULE stricte. Sereno ne tient pas
# de comptabilité en partie double : ce service RECONSTITUE des écritures
# depuis les documents déjà émis (factures, avoirs, paiements confirmés).
#
# ⚠️ DEUX GARDE-FOUS (§1 execution_export_fec_mvp.txt), non négociables :
#   1) RÉUTILISE VERBATIM les montants déjà calculés par FactureTotalsService
#      / AvoirTotalsService (GELÉS STRICTS, lus jamais modifiés — même usage
#      que factur_x_xml_service.rb) : total_ttc et groupes_tva viennent du
#      MÊME `Result` pour une écriture donnée, jamais un recalcul indépendant
#      ni un mélange colonne-stockée/valeur-recalculée. Comme chaque valeur
#      de ligne (`total_ht`) est déjà arrondie au centime, sommer des valeurs
#      déjà arrondies (BigDecimal, arithmétique exacte) ne réintroduit AUCUN
#      écart : somme(base_ht par groupe) == total_ht, somme(montant_tva par
#      groupe) == total_tva, TOUJOURS. L'équilibre 411 == 707+44571 est donc
#      garanti PAR CONSTRUCTION, pas par une réconciliation a posteriori.
#   2) MVP = TVA à la date de FACTURE, quel que soit `fait_generateur_tva`
#      (le raffinement "TVA sur encaissements" — compte d'attente + transfert
#      — est HORS périmètre, cf. dette consignée). Aucune ligne de TVA à
#      l'encaissement.
#
# Comptes PAR DÉFAUT, en dur (aucun plan comptable n'existe dans Sereno,
# cf. reco du 15/08/2026) : 411 Clients, 707 Ventes, 44571 TVA collectée,
# 512 Banque, 531 Caisse. Personnalisation par organisation = fast-follow
# (dette consignée).
class FecExportService
  SEPARATEUR = "\t"

  ENTETE = %w[
    JournalCode JournalLib EcritureNum EcritureDate CompteNum CompteLib
    CompAuxNum CompAuxLib PieceRef PieceDate EcritureLib Debit Credit
    EcritureLet DateLet ValidDate Montantdevise Idevise
  ].freeze

  COMPTE_CLIENT = "411"
  COMPTE_VENTE = "707"
  COMPTE_TVA_COLLECTEE = "44571"
  COMPTE_BANQUE = "512"
  COMPTE_CAISSE = "531"

  LIBELLES_COMPTES = {
    COMPTE_CLIENT => "Clients",
    COMPTE_VENTE => "Ventes",
    COMPTE_TVA_COLLECTEE => "TVA collectée",
    COMPTE_BANQUE => "Banque",
    COMPTE_CAISSE => "Caisse"
  }.freeze

  METHODE_ESPECES = "10"

  Result = Struct.new(:contenu, :nom_fichier, :etiquette, keyword_init: true)

  def initialize(organisation:, debut:, fin:)
    @organisation = organisation
    @debut = debut
    @fin = fin
    @compteur_ecriture = 0
  end

  def call
    raise ArgumentError, "debut doit être antérieur ou égal à fin" if @debut > @fin

    lignes = []

    factures_eligibles.each { |facture| lignes.concat(ecritures_vente(facture)) }
    avoirs_eligibles.each { |avoir| lignes.concat(ecritures_avoir(avoir)) }
    paiements_eligibles.each { |paiement| lignes.concat(ecritures_encaissement(paiement)) }

    Result.new(contenu: construire_contenu(lignes), nom_fichier: nom_fichier, etiquette: etiquette)
  end

  # Texte d'honnêteté (§6) — vit dans l'UI/la réponse API, JAMAIS dans le
  # fichier .txt lui-même (qui reste strictement au format DGFiP). Public et
  # indépendant de #call : le contrôleur l'utilise pour un aperçu AVANT
  # même de lancer l'export (l'étiquette ne dépend que du régime déclaré,
  # pas de la plage de dates).
  def etiquette
    "FEC reconstitué automatiquement à partir des factures, avoirs et paiements de " \
      "Sereno — ce n'est pas une comptabilité tenue. TVA comptabilisée à la date de " \
      "facture. Régime déclaré : #{@organisation.fait_generateur_tva}. À faire " \
      "valider par un expert-comptable avant tout usage fiscal."
  end

  # Convention DGFiP : <SIREN>FEC<AAAAMMJJ_fin>.txt — SIREN = 9 premiers
  # chiffres du SIRET de l'organisation (14 chiffres, validé au modèle).
  # Public, même raison que #etiquette : utile pour un aperçu.
  def nom_fichier
    siren = @organisation.siret.to_s[0, 9]
    "#{siren}FEC#{@fin.strftime('%Y%m%d')}.txt"
  end

  private

  # --- Sélection des documents (tenant-scopé, bornage par date) ---

  def factures_eligibles
    @organisation.factures
      .where.not(statut: "brouillon")
      .where(date_emission: @debut..@fin)
      .includes(:client, :lignes_facture)
      .order(:date_emission, :numero)
  end

  def avoirs_eligibles
    @organisation.avoirs
      .where.not(statut: "brouillon")
      .where(date_emission: @debut..@fin)
      .includes(:client, :facture, :lignes_avoir)
      .order(:date_emission, :numero)
  end

  def paiements_eligibles
    @organisation.paiements
      .where(statut: "confirme")
      .where(date_encaissement: @debut..@fin)
      .includes(facture: :client)
      .order(:date_encaissement, :created_at)
  end

  # --- Construction des écritures (une par document) ---

  # VENTE : 411 débit TTC == somme(707 crédit base_ht) + somme(44571 crédit
  # montant_tva). Ligne 44571 OMISE quand montant_tva = 0 (ex. franchise).
  def ecritures_vente(facture)
    totaux = FactureTotalsService.new(facture: facture).call
    client = facture.client
    ecriture_num = prochain_numero_ecriture!
    ecriture_lib = "Facture #{facture.numero} — #{client.raison_sociale}"

    lignes = [
      ligne_fec(
        ecriture_num: ecriture_num, journal_code: "VE", journal_lib: "Ventes",
        ecriture_date: facture.date_emission, compte_num: COMPTE_CLIENT,
        comp_aux_num: compte_auxiliaire(client), comp_aux_lib: client.raison_sociale,
        piece_ref: facture.numero, piece_date: facture.date_emission,
        ecriture_lib: ecriture_lib, debit: totaux.total_ttc
      )
    ]

    groupes_tries(totaux.groupes_tva).each do |_cle, groupe|
      lignes << ligne_fec(
        ecriture_num: ecriture_num, journal_code: "VE", journal_lib: "Ventes",
        ecriture_date: facture.date_emission, compte_num: COMPTE_VENTE,
        piece_ref: facture.numero, piece_date: facture.date_emission,
        ecriture_lib: ecriture_lib, credit: groupe[:base_ht]
      )

      next unless groupe[:montant_tva].positive?

      lignes << ligne_fec(
        ecriture_num: ecriture_num, journal_code: "VE", journal_lib: "Ventes",
        ecriture_date: facture.date_emission, compte_num: COMPTE_TVA_COLLECTEE,
        piece_ref: facture.numero, piece_date: facture.date_emission,
        ecriture_lib: ecriture_lib, credit: groupe[:montant_tva]
      )
    end

    lignes
  end

  # AVOIR : écriture MIROIR de la vente — 411 crédit TTC == somme(707 débit)
  # + somme(44571 débit).
  def ecritures_avoir(avoir)
    totaux = AvoirTotalsService.new(avoir: avoir).call
    client = avoir.client
    ecriture_num = prochain_numero_ecriture!
    ecriture_lib = "Avoir #{avoir.numero} (réf facture #{avoir.facture.numero}) — #{client.raison_sociale}"

    lignes = [
      ligne_fec(
        ecriture_num: ecriture_num, journal_code: "VE", journal_lib: "Ventes",
        ecriture_date: avoir.date_emission, compte_num: COMPTE_CLIENT,
        comp_aux_num: compte_auxiliaire(client), comp_aux_lib: client.raison_sociale,
        piece_ref: avoir.numero, piece_date: avoir.date_emission,
        ecriture_lib: ecriture_lib, credit: totaux.total_ttc
      )
    ]

    groupes_tries(totaux.groupes_tva).each do |_cle, groupe|
      lignes << ligne_fec(
        ecriture_num: ecriture_num, journal_code: "VE", journal_lib: "Ventes",
        ecriture_date: avoir.date_emission, compte_num: COMPTE_VENTE,
        piece_ref: avoir.numero, piece_date: avoir.date_emission,
        ecriture_lib: ecriture_lib, debit: groupe[:base_ht]
      )

      next unless groupe[:montant_tva].positive?

      lignes << ligne_fec(
        ecriture_num: ecriture_num, journal_code: "VE", journal_lib: "Ventes",
        ecriture_date: avoir.date_emission, compte_num: COMPTE_TVA_COLLECTEE,
        piece_ref: avoir.numero, piece_date: avoir.date_emission,
        ecriture_lib: ecriture_lib, debit: groupe[:montant_tva]
      )
    end

    lignes
  end

  # ENCAISSEMENT : PAS de ligne de TVA (déjà écrite à la facture, MVP).
  # Espèces (methode_code "10") -> 531/Caisse ; tout le reste (20/48/58/59,
  # tous dématérialisés) -> 512/Banque.
  def ecritures_encaissement(paiement)
    facture = paiement.facture
    client = facture.client
    ecriture_num = prochain_numero_ecriture!
    especes = paiement.methode_code == METHODE_ESPECES
    compte_tresorerie = especes ? COMPTE_CAISSE : COMPTE_BANQUE
    journal_code = especes ? "CA" : "BQ"
    journal_lib = especes ? "Caisse" : "Banque"
    piece_ref = paiement.reference.presence || paiement.id
    ecriture_lib = "Encaissement facture #{facture.numero} — #{client.raison_sociale}"

    [
      ligne_fec(
        ecriture_num: ecriture_num, journal_code: journal_code, journal_lib: journal_lib,
        ecriture_date: paiement.date_encaissement, compte_num: compte_tresorerie,
        piece_ref: piece_ref, piece_date: paiement.date_encaissement,
        ecriture_lib: ecriture_lib, debit: paiement.montant
      ),
      ligne_fec(
        ecriture_num: ecriture_num, journal_code: journal_code, journal_lib: journal_lib,
        ecriture_date: paiement.date_encaissement, compte_num: COMPTE_CLIENT,
        comp_aux_num: compte_auxiliaire(client), comp_aux_lib: client.raison_sociale,
        piece_ref: piece_ref, piece_date: paiement.date_encaissement,
        ecriture_lib: ecriture_lib, credit: paiement.montant
      )
    ]
  end

  # --- Détail d'une ligne FEC (les 18 champs, DANS L'ORDRE d'ENTETE) ---

  def ligne_fec(ecriture_num:, journal_code:, journal_lib:, ecriture_date:, compte_num:,
                piece_ref:, piece_date:, ecriture_lib:,
                comp_aux_num: nil, comp_aux_lib: nil,
                debit: FactureTotalsService::ZERO, credit: FactureTotalsService::ZERO)
    [
      journal_code,
      journal_lib,
      ecriture_num.to_s,
      formater_date(ecriture_date),
      compte_num,
      LIBELLES_COMPTES.fetch(compte_num, compte_num),
      comp_aux_num.to_s,
      comp_aux_lib.to_s,
      piece_ref.to_s,
      formater_date(piece_date),
      ecriture_lib,
      formater_montant(debit),
      formater_montant(credit),
      "", # EcritureLet — lettrage absent de Sereno
      "", # DateLet — idem
      formater_date(ecriture_date), # ValidDate = EcritureDate (immutabilité post-émission)
      "", # Montantdevise — tout est EUR aujourd'hui
      ""  # Idevise — idem
    ]
  end

  def prochain_numero_ecriture!
    @compteur_ecriture += 1
  end

  def compte_auxiliaire(client)
    client.siret.presence || client.id
  end

  # Tri déterministe (clé "CATEGORIE-TAUX", ex. "S-20.00") — reproductible
  # d'un export à l'autre pour le même document.
  def groupes_tries(groupes_tva)
    groupes_tva.sort_by { |cle, _groupe| cle }
  end

  def formater_date(date)
    date.strftime("%Y%m%d")
  end

  def formater_montant(valeur)
    format("%.2f", FactureTotalsService.decimal(valeur)).tr(".", ",")
  end

  def construire_contenu(lignes)
    ([ ENTETE ] + lignes).map { |ligne| ligne.join(SEPARATEUR) }.join("\n")
  end
end
