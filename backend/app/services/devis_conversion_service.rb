# frozen_string_literal: true

# LE CŒUR voie (b) : un devis ACCEPTÉ devient une VRAIE facture. Ce service
# n'écrit AUCUN code légal — il assemble une facture brouillon par le MÊME
# chemin qu'une création manuelle (Api::V1::FacturesController#create), puis
# APPELLE FactureEmissionService (GELÉ STRICT) tel quel.
#
# Contrairement à AvoirEmissionService (qui, lui, DOIT régénérer son propre
# XML/PDF car un avoir est un document légal à part entière), ce service ne
# duplique AUCUN moteur d'émission : un devis n'est jamais un document légal,
# la facture qui sort de la conversion est indiscernable d'une facture créée
# à la main, parce qu'elle emprunte EXACTEMENT le même chemin.
class DevisConversionService
  class ConversionImpossibleError < StandardError
    attr_reader :details

    def initialize(message = "Conversion impossible", details: [])
      @details = Array(details)
      @details = [ message ] if @details.empty?

      super(message)
    end
  end

  def initialize(devis:, utilisateur:)
    @devis = devis
    @organisation = devis.organisation
    @utilisateur = utilisateur
  end

  def call
    ActiveRecord::Base.transaction do
      @devis.lock!

      # Gardes vérifiées SUR L'ÉTAT VERROUILLÉ (après lock!, qui recharge
      # les attributs depuis la ligne verrouillée) : ce qui rend
      # l'idempotence robuste à une conversion concurrente, pas seulement
      # une vérification optimiste avant la transaction.
      verifier_eligibilite!

      facture = construire_facture_brouillon!
      copier_lignes!(facture)

      # Le chemin d'émission EXACT : numéro FAC-ANNEE-xxxx, conformité
      # pré-émission bloquante, XML CII, PDF/A-3, statut "emise",
      # EvenementFacture. AUCUN nouveau code légal, AUCUNE duplication.
      # Si ça échoue (ex. conformité), l'exception remonte et annule TOUTE
      # la transaction (facture brouillon + lignes copiées comprises) :
      # aucune facture orpheline ne peut subsister.
      facture_emise = FactureEmissionService.new(
        facture: facture,
        utilisateur: @utilisateur
      ).call

      creer_evenement_conversion!(facture_emise)

      facture_emise
    end
  end

  private

  # ⚠️ `details:` est ce que le contrôleur renvoie réellement au client (cf.
  # Api::V1::DevisController#convertir : `render json: { ..., details: e.details }`,
  # même convention que FactureEmissionService::EmissionImpossibleError) — le
  # message humain doit donc être DANS details, pas seulement en `message`
  # d'exception (qui n'est jamais sérialisé).
  def verifier_eligibilite!
    if @devis.converti?
      facture_existante = @devis.facture_generee
      message = "Ce devis est déjà converti en facture #{facture_existante&.numero} (id: #{facture_existante&.id})"

      raise ConversionImpossibleError.new(message, details: [ message ])
    end

    return if @devis.statut == "accepte"

    message = "Le devis doit être accepté avant conversion (statut actuel : #{@devis.statut})"
    raise ConversionImpossibleError.new(message, details: [ message ])
  end

  # Mêmes attributs par défaut que
  # Api::V1::FacturesController#default_facture_attributes, lus tels quels à
  # l'étape 0 — + client et devis (le lien). Ni date_emission ni
  # date_echeance ne sont fixées ici : une facture manuelle créée sans
  # préciser d'échéance reste sur ce même défaut (nil), et date_emission
  # n'est de toute façon écrite QUE par FactureEmissionService, à l'émission
  # (étape suivante). ⚠️ La date_validite du devis n'est JAMAIS recopiée
  # ici : elle mesure la validité d'une OFFRE, sans rapport avec l'échéance
  # de PAIEMENT d'une facture — les confondre serait un bug métier.
  def construire_facture_brouillon!
    facture = @organisation.factures.new(
      type_document: "facture",
      statut: "brouillon",
      total_ht: 0,
      total_tva: 0,
      total_ttc: 0,
      montant_paye: 0,
      devise: "EUR",
      format: "factur_x",
      client: @devis.client,
      devis: @devis
    )

    facture.save!
    facture
  end

  # Copie LigneDevis -> LigneFacture : uniquement les champs SOURCE
  # (désignation, quantité, prix unitaire, taux TVA, position). Les montants
  # (total_ht/montant_tva/total_ttc) ne sont PAS copiés : LigneFacture les
  # recalcule elle-même via FactureTotalsService.calculer_ligne
  # (before_validation), exactement comme une saisie manuelle. C'est ce qui
  # PROUVE — et ne suppose jamais — que facture.total == devis.total : les
  # deux passent par le même moteur de calcul gelé.
  def copier_lignes!(facture)
    @devis.lignes_devis.order(:position).each do |ligne_devis|
      LigneFacture.create!(
        organisation: @organisation,
        facture: facture,
        designation: ligne_devis.designation,
        quantite: ligne_devis.quantite,
        prix_unitaire_ht: ligne_devis.prix_unitaire_ht,
        taux_tva: ligne_devis.taux_tva,
        position: ligne_devis.position
      )
    end
  end

  def creer_evenement_conversion!(facture)
    EvenementDevis.create!(
      organisation_id: @organisation.id,
      devis_id: @devis.id,
      utilisateur_id: @utilisateur&.id,
      statut: @devis.statut,
      source: "interne",
      payload: {
        action: "devis_converti",
        facture_id: facture.id,
        facture_numero: facture.numero
      }
    )
  end
end
