# frozen_string_literal: true

# Voie (b) : miroir de FactureConformiteService (GELÉ STRICT — jamais
# modifié). Reprend les contrôles transposables (organisation, client,
# lignes, cohérence des totaux, franchise de TVA) et ajoute le contrôle
# SPÉCIFIQUE à l'avoir : référence obligatoire à une facture ÉMISE (BT-25),
# et cohérence du montant crédité avec le montant de la facture corrigée.
#
# ligne_avoir ne porte pas montant_tva/total_ttc par ligne (contrairement à
# ligne_facture) : la vérification ligne à ligne se limite donc au total_ht.
# Avoir n'a pas de colonne devise/format/type_document/date_echeance/
# conditions_paiement : ces contrôles n'ont pas d'équivalent ici, l'avoir
# hérite silencieusement du contexte de sa facture (devise notamment, lue
# directement par AvoirXmlService).
class AvoirConformiteService
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

  def initialize(avoir:)
    @avoir = avoir
    @erreurs = []
    @avertissements = []
  end

  def call
    verifier_avoir_presence
    return resultat if @avoir.blank?

    verifier_statut_avoir
    verifier_reference_facture
    verifier_organisation
    verifier_client
    verifier_lignes
    verifier_totaux
    verifier_montant_avoir_positif
    verifier_montant_coherent_avec_facture
    verifier_coherence_franchise_tva
    verifier_motif

    resultat
  end

  private

  def resultat
    Result.new(erreurs: @erreurs, avertissements: @avertissements)
  end

  def verifier_avoir_presence
    @erreurs << "L'avoir est introuvable" if @avoir.blank?
  end

  def verifier_statut_avoir
    @erreurs << "L'avoir doit être en brouillon" unless @avoir.brouillon?
    @erreurs << "L'avoir possède déjà un numéro" if @avoir.numero.present?
  end

  # LE contrôle spécifique à l'avoir (§1 du prompt) : sans référence à une
  # facture ÉMISE, un avoir n'a pas de valeur légale (BT-25).
  def verifier_reference_facture
    facture = @avoir.facture

    if facture.blank?
      @erreurs << "L'avoir doit référencer une facture"
      return
    end

    if facture.organisation_id != @avoir.organisation_id
      @erreurs << "La facture référencée n'appartient pas à la même organisation que l'avoir"
    end

    if facture.brouillon?
      @erreurs << "La facture référencée doit avoir été émise, pas rester à l'état de brouillon"
    end

    @erreurs << "La facture référencée doit avoir un numéro (BT-25)" if facture.numero.blank?
  end

  def verifier_organisation
    organisation = @avoir.organisation

    if organisation.blank?
      @erreurs << "L'avoir doit être lié à une organisation émettrice"
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
      @erreurs << "L'organisation émettrice doit avoir un numéro de TVA si l'avoir contient de la TVA"
    end
  end

  def verifier_client
    client = @avoir.client

    if client.blank?
      @erreurs << "L'avoir doit être lié à un client"
      return
    end

    if client.organisation_id != @avoir.organisation_id
      @erreurs << "Le client n'appartient pas à la même organisation que l'avoir"
    end

    @erreurs << "Le client doit avoir une raison sociale" if client.raison_sociale.blank?
    @erreurs << "Le client doit avoir une adresse" if client.adresse_ligne1.blank?
    @erreurs << "Le client doit avoir un code postal" if client.code_postal.blank?
    @erreurs << "Le client doit avoir une ville" if client.ville.blank?
    @erreurs << "Le client doit avoir un pays" if client.pays.blank?

    verifier_siret_client_entreprise(client)
  end

  def verifier_siret_client_entreprise(client)
    return unless client.type == "entreprise"

    @erreurs << "Le client entreprise doit avoir un SIRET" if client.siret.blank?

    if client.siret.present? && client.siret !~ FORMAT_SIRET
      @erreurs << "Le SIRET client doit contenir 14 chiffres"
    end
  end

  def verifier_lignes
    lignes = lignes_avoir

    if lignes.empty?
      @erreurs << "L'avoir doit contenir au moins une ligne"
      return
    end

    lignes.each_with_index do |ligne, index|
      numero_ligne = index + 1

      @erreurs << "Ligne #{numero_ligne} : la désignation est obligatoire" if ligne.designation.blank?
      @erreurs << "Ligne #{numero_ligne} : la quantité doit être supérieure à 0" unless decimal(ligne.quantite).positive?
      @erreurs << "Ligne #{numero_ligne} : le prix unitaire HT doit être positif ou nul" if decimal(ligne.prix_unitaire_ht).negative?
      @erreurs << "Ligne #{numero_ligne} : le taux de TVA doit être positif ou nul" if decimal(ligne.taux_tva).negative?

      verifier_total_ligne(ligne, numero_ligne)
    end
  end

  def verifier_total_ligne(ligne, numero_ligne)
    montants_attendus = FactureTotalsService.calculer_ligne(
      quantite: ligne.quantite,
      prix_unitaire_ht: ligne.prix_unitaire_ht,
      taux_tva: ligne.taux_tva
    )

    return if proche?(ligne.total_ht, montants_attendus[:total_ht])

    @erreurs << "Ligne #{numero_ligne} : le total HT est incohérent"
  end

  def verifier_totaux
    totaux_attendus = AvoirTotalsService.new(avoir: @avoir).call

    unless proche?(@avoir.total_ht, totaux_attendus.total_ht)
      @erreurs << "Le total HT de l'avoir est incohérent"
    end

    unless proche?(@avoir.total_tva, totaux_attendus.total_tva)
      @erreurs << "Le total TVA de l'avoir est incohérent"
    end

    unless proche?(@avoir.total_ttc, totaux_attendus.total_ttc)
      @erreurs << "Le total TTC de l'avoir est incohérent"
    end

    @erreurs << "Le total TTC doit être supérieur à 0" unless decimal(@avoir.total_ttc).positive?
  end

  def verifier_montant_avoir_positif
    lignes = lignes_avoir
    return if lignes.empty?

    ligne_positive = lignes.any? do |ligne|
      decimal(ligne.total_ht).positive? &&
        decimal(ligne.quantite).positive? &&
        decimal(ligne.prix_unitaire_ht).positive?
    end

    unless ligne_positive
      @erreurs << "L'avoir doit contenir au moins une ligne avec un montant HT positif"
    end
  end

  # Invariant réel (indépendant de la notion total/partiel, cf. §5 du
  # prompt : aucune colonne « type » introduite en V1.2a) : la somme de TOUS
  # les avoirs déjà émis sur une facture, plus celui-ci, ne peut jamais
  # dépasser le montant TTC de la facture corrigée.
  def verifier_montant_coherent_avec_facture
    facture = @avoir.facture
    return if facture.blank?

    deja_credite = facture.avoirs
      .where.not(id: @avoir.id)
      .where.not(statut: "brouillon")
      .sum(:total_ttc)

    montant_total_credite = decimal(deja_credite) + decimal(@avoir.total_ttc)

    return unless montant_total_credite > decimal(facture.total_ttc) + TOLERANCE_CENTIME

    @erreurs << "Le montant total des avoirs émis sur cette facture ne peut pas dépasser son montant TTC"
  end

  def verifier_coherence_franchise_tva
    organisation = @avoir.organisation
    return if organisation.blank?

    if organisation.regime_tva == "franchise"
      verifier_franchise_sans_tva
    end
  end

  def verifier_franchise_sans_tva
    if decimal(@avoir.total_tva).positive?
      @erreurs << "Une organisation en franchise de TVA ne peut pas émettre un avoir avec de la TVA"
    end

    lignes_avoir.each_with_index do |ligne, index|
      numero_ligne = index + 1

      if decimal(ligne.taux_tva).positive?
        @erreurs << "Ligne #{numero_ligne} : le taux de TVA doit être à 0 pour une organisation en franchise de TVA"
      end
    end
  end

  def verifier_motif
    @erreurs << "Le motif de l'avoir est obligatoire" if @avoir.motif.blank?
  end

  def tva_facturee?
    return true if decimal(@avoir.total_tva).positive?

    lignes_avoir.any? { |ligne| decimal(ligne.taux_tva).positive? }
  end

  def lignes_avoir
    @lignes_avoir ||= @avoir.lignes_avoir.order(:position).to_a
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
