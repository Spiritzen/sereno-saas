# frozen_string_literal: true

class FactureConformiteService
  Result = Struct.new(:erreurs, :avertissements, keyword_init: true) do
    def conforme?
      erreurs.empty?
    end

    def to_h
      {
        conforme: conforme?,
        erreurs: erreurs,
        avertissements: avertissements
      }
    end
  end

  TOLERANCE_CENTIME = BigDecimal("0.01")
  FORMAT_SIRET = /\A\d{14}\z/

  def initialize(facture:)
    @facture = facture
    @erreurs = []
    @avertissements = []
  end

  def call
    verifier_facture_presence
    return resultat if @facture.blank?

    verifier_statut_facture
    verifier_organisation
    verifier_client
    verifier_client_public
    verifier_lignes
    verifier_totaux
    verifier_montant_facture_positif
    verifier_coherence_franchise_tva
    verifier_informations_generales

    resultat
  end

  private

  def resultat
    Result.new(
      erreurs: @erreurs,
      avertissements: @avertissements
    )
  end

  def verifier_facture_presence
    @erreurs << "La facture est introuvable" if @facture.blank?
  end

  def verifier_statut_facture
    @erreurs << "La facture doit être en brouillon" unless @facture.brouillon?
    @erreurs << "La facture possède déjà un numéro" if @facture.numero.present?
  end

  def verifier_organisation
    organisation = @facture.organisation

    if organisation.blank?
      @erreurs << "La facture doit être liée à une organisation émettrice"
      return
    end

    @erreurs << "L'organisation émettrice doit avoir une raison sociale" if organisation.raison_sociale.blank?
    @erreurs << "L'organisation émettrice doit avoir un SIRET" if organisation.siret.blank?

    if organisation.siret.present? && organisation.siret !~ FORMAT_SIRET
      @erreurs << "Le SIRET de l'organisation émettrice doit contenir 14 chiffres"
    end

    @erreurs << "L'organisation émettrice doit avoir une adresse" if organisation.adresse_ligne1.blank?
    @erreurs << "L'organisation émettrice doit avoir un code postal" if organisation.code_postal.blank?
    @erreurs << "L'organisation émettrice doit avoir une ville" if organisation.ville.blank?
    @erreurs << "L'organisation émettrice doit avoir un pays" if organisation.pays.blank?

    if tva_facturee? && organisation.numero_tva.blank?
      @erreurs << "L'organisation émettrice doit avoir un numéro de TVA si la facture contient de la TVA"
    end
  end

  def verifier_client
    client = @facture.client

    if client.blank?
      @erreurs << "La facture doit être liée à un client"
      return
    end

    if client.organisation_id != @facture.organisation_id
      @erreurs << "Le client n'appartient pas à la même organisation que la facture"
    end

    @erreurs << "Le client doit avoir une raison sociale" if client.raison_sociale.blank?
    @erreurs << "Le client doit avoir une adresse" if client.adresse_ligne1.blank?
    @erreurs << "Le client doit avoir un code postal" if client.code_postal.blank?
    @erreurs << "Le client doit avoir une ville" if client.ville.blank?
    @erreurs << "Le client doit avoir un pays" if client.pays.blank?

    verifier_siret_client_entreprise(client)

    if client.identifiant_routage_pa.blank?
      @avertissements << "Le client n'a pas d'identifiant de routage PA"
    end

    @erreurs << "Le client est archivé : impossible d'émettre une facture" if client.archive?
  end

  def verifier_siret_client_entreprise(client)
    return unless client.type == "entreprise"

    @erreurs << "Le client entreprise doit avoir un SIRET" if client.siret.blank?

    if client.siret.present? && client.siret !~ FORMAT_SIRET
      @erreurs << "Le SIRET client doit contenir 14 chiffres"
    end
  end

  def verifier_client_public
    client = @facture.client
    return if client.blank?
    return unless client.type == "public"

    @erreurs << "Le client public doit avoir un SIRET" if client.siret.blank?

    if client.siret.present? && client.siret !~ FORMAT_SIRET
      @erreurs << "Le SIRET du client public doit contenir 14 chiffres"
    end

    if client.identifiant_routage_pa.blank?
      @erreurs << "Le client public doit avoir un identifiant de routage PA"
    end
  end

  def verifier_lignes
    lignes = lignes_facture

    if lignes.empty?
      @erreurs << "La facture doit contenir au moins une ligne"
      return
    end

    lignes.each_with_index do |ligne, index|
      numero_ligne = index + 1

      @erreurs << "Ligne #{numero_ligne} : la désignation est obligatoire" if ligne.designation.blank?
      @erreurs << "Ligne #{numero_ligne} : la quantité doit être supérieure à 0" unless decimal(ligne.quantite).positive?
      @erreurs << "Ligne #{numero_ligne} : le prix unitaire HT doit être positif ou nul" if decimal(ligne.prix_unitaire_ht).negative?
      @erreurs << "Ligne #{numero_ligne} : le taux de TVA doit être positif ou nul" if decimal(ligne.taux_tva).negative?

      verifier_totaux_ligne(ligne, numero_ligne)
    end
  end

  def verifier_totaux_ligne(ligne, numero_ligne)
    montants_attendus = FactureTotalsService.calculer_ligne(
      quantite: ligne.quantite,
      prix_unitaire_ht: ligne.prix_unitaire_ht,
      taux_tva: ligne.taux_tva
    )

    unless proche?(ligne.total_ht, montants_attendus[:total_ht])
      @erreurs << "Ligne #{numero_ligne} : le total HT est incohérent"
    end

    unless proche?(ligne.montant_tva, montants_attendus[:montant_tva])
      @erreurs << "Ligne #{numero_ligne} : le montant de TVA est incohérent"
    end

    unless proche?(ligne.total_ttc, montants_attendus[:total_ttc])
      @erreurs << "Ligne #{numero_ligne} : le total TTC est incohérent"
    end
  end

  def verifier_totaux
    totaux_attendus = FactureTotalsService.new(facture: @facture).call

    unless proche?(@facture.total_ht, totaux_attendus.total_ht)
      @erreurs << "Le total HT de la facture est incohérent"
    end

    unless proche?(@facture.total_tva, totaux_attendus.total_tva)
      @erreurs << "Le total TVA de la facture est incohérent"
    end

    unless proche?(@facture.total_ttc, totaux_attendus.total_ttc)
      @erreurs << "Le total TTC de la facture est incohérent"
    end

    @erreurs << "Le total TTC doit être supérieur à 0" unless decimal(@facture.total_ttc).positive?
  end

  def verifier_montant_facture_positif
    lignes = lignes_facture

    return if lignes.empty?

    total_ht = decimal(@facture.total_ht)

    ligne_positive = lignes.any? do |ligne|
      decimal(ligne.total_ht).positive? &&
        decimal(ligne.quantite).positive? &&
        decimal(ligne.prix_unitaire_ht).positive?
    end

    unless ligne_positive
      @erreurs << "La facture doit contenir au moins une ligne avec un montant HT positif"
    end

    unless total_ht.positive?
      @erreurs << "Le total HT de la facture doit être supérieur à 0"
    end
  end

  def verifier_coherence_franchise_tva
    organisation = @facture.organisation
    return if organisation.blank?

    if organisation.regime_tva == "franchise"
      verifier_franchise_sans_tva
    end

    verifier_mention_293b_incoherente
  end

  def verifier_franchise_sans_tva
    if decimal(@facture.total_tva).positive?
      @erreurs << "Une organisation en franchise de TVA ne peut pas émettre une facture avec de la TVA"
    end

    lignes_facture.each_with_index do |ligne, index|
      numero_ligne = index + 1

      if decimal(ligne.taux_tva).positive?
        @erreurs << "Ligne #{numero_ligne} : le taux de TVA doit être à 0 pour une organisation en franchise de TVA"
      end

      if decimal(ligne.montant_tva).positive?
        @erreurs << "Ligne #{numero_ligne} : le montant de TVA doit être à 0 pour une organisation en franchise de TVA"
      end
    end
  end

  def verifier_mention_293b_incoherente
    return unless tva_facturee?

    texte_mentions = [
      @facture.mentions,
      @facture.organisation&.mentions_legales
    ].compact.join(" ")

    return unless texte_mentions.match?(/293\s*B/i)

    @erreurs << "La mention 'TVA non applicable, art. 293 B du CGI' ne doit pas être utilisée sur une facture avec TVA"
  end

  def verifier_informations_generales
    @erreurs << "La devise est obligatoire" if @facture.devise.blank?
    @erreurs << "Le format de facture est obligatoire" if @facture.format.blank?
    @erreurs << "Le type de document est obligatoire" if @facture.type_document.blank?

    @avertissements << "La date d'échéance n'est pas renseignée" if @facture.date_echeance.blank?
    @avertissements << "Les conditions de paiement ne sont pas renseignées" if @facture.conditions_paiement.blank?
    @avertissements << "Le format attendu pour le MVP est factur_x" if @facture.format.present? && @facture.format != "factur_x"
  end

  def tva_facturee?
    return true if decimal(@facture.total_tva).positive?

    lignes_facture.any? do |ligne|
      decimal(ligne.taux_tva).positive? || decimal(ligne.montant_tva).positive?
    end
  end

  def lignes_facture
    @lignes_facture ||= @facture.lignes_facture.order(:position).to_a
  end

  def proche?(valeur_reelle, valeur_attendue)
    (decimal(valeur_reelle) - decimal(valeur_attendue)).abs <= TOLERANCE_CENTIME
  end

  def decimal(valeur)
    BigDecimal(valeur.to_s)
  rescue ArgumentError, TypeError
    BigDecimal("0")
  end
end
