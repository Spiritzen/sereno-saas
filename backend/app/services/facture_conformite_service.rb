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

  def initialize(facture:)
    @facture = facture
    @erreurs = []
    @avertissements = []
  end

  def call
    verifier_facture_presence
    return resultat if @facture.blank?

    verifier_statut_facture
    verifier_client
    verifier_lignes
    verifier_totaux
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

    if client.type == "entreprise"
      @erreurs << "Le client entreprise doit avoir un SIRET" if client.siret.blank?
      @erreurs << "Le SIRET client doit contenir 14 chiffres" if client.siret.present? && client.siret !~ /\A\d{14}\z/
    end

    @avertissements << "Le client n'a pas d'identifiant de routage PA" if client.identifiant_routage_pa.blank?
    @avertissements << "Le client est archivé" if client.respond_to?(:archive?) && client.archive?
  end

  def verifier_lignes
    lignes = @facture.lignes_facture.order(:position)

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
    total_ht_attendu = decimal(ligne.quantite) * decimal(ligne.prix_unitaire_ht)
    montant_tva_attendu = total_ht_attendu * decimal(ligne.taux_tva) / 100
    total_ttc_attendu = total_ht_attendu + montant_tva_attendu

    unless proche?(ligne.total_ht, total_ht_attendu)
      @erreurs << "Ligne #{numero_ligne} : le total HT est incohérent"
    end

    unless proche?(ligne.montant_tva, montant_tva_attendu)
      @erreurs << "Ligne #{numero_ligne} : le montant de TVA est incohérent"
    end

    unless proche?(ligne.total_ttc, total_ttc_attendu)
      @erreurs << "Ligne #{numero_ligne} : le total TTC est incohérent"
    end
  end

  def verifier_totaux
    lignes = @facture.lignes_facture

    total_ht_attendu = lignes.sum(:total_ht)
    total_tva_attendu = lignes.sum(:montant_tva)
    total_ttc_attendu = lignes.sum(:total_ttc)

    unless proche?(@facture.total_ht, total_ht_attendu)
      @erreurs << "Le total HT de la facture est incohérent"
    end

    unless proche?(@facture.total_tva, total_tva_attendu)
      @erreurs << "Le total TVA de la facture est incohérent"
    end

    unless proche?(@facture.total_ttc, total_ttc_attendu)
      @erreurs << "Le total TTC de la facture est incohérent"
    end

    @erreurs << "Le total TTC doit être supérieur à 0" unless decimal(@facture.total_ttc).positive?
  end

  def verifier_informations_generales
    @erreurs << "La devise est obligatoire" if @facture.devise.blank?
    @erreurs << "Le format de facture est obligatoire" if @facture.format.blank?
    @erreurs << "Le type de document est obligatoire" if @facture.type_document.blank?

    @avertissements << "La date d'échéance n'est pas renseignée" if @facture.date_echeance.blank?
    @avertissements << "Les conditions de paiement ne sont pas renseignées" if @facture.conditions_paiement.blank?
    @avertissements << "Le format attendu pour le MVP est factur_x" if @facture.format.present? && @facture.format != "factur_x"
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
