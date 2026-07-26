# frozen_string_literal: true

# Voie (b) — V1.2a : produit le CII d'un AVOIR (TypeCode 381), avec sa
# référence obligatoire à la facture corrigée (BT-25). Dupliqué-adapté
# depuis FacturXXmlService (GELÉ STRICT — jamais modifié, jamais hérité :
# une constante référencée nue dans une méthode Ruby se résout par scope
# LEXICAL, pas par polymorphisme sur une sous-classe — hériter et redéfinir
# DOCUMENT_TYPE_CODE n'aurait aucun effet sur le XML produit par les
# méthodes héritées). Ce fichier est un NOUVEAU service, sans lien de code
# avec le gelé au-delà de l'appel (lecture seule) à FactureTotalsService et
# FactureStatusTransitionPolicy... — en réalité aucun appel direct au gelé
# ici, tout calcul passe par AvoirTotalsService (qui, lui, réutilise les
# méthodes de classe pures du gelé, cf. son propre commentaire).
#
# DETTE CONNUE (voie b, actée par le prompt B3.3/V1.2) : ce fichier duplique
# la structure CII de FacturXXmlService. Toute évolution future des règles
# EN16931/France CTC sur le 380 (BT-22, ordre des éléments, mentions...)
# devra être répercutée manuellement ici pour le 381. Alternative rejetée :
# modifier/hériter du moteur gelé (voir SOCLE_GELE.md — interdit sans
# re-validation complète et décision explicite de Sébastien).
class AvoirXmlService
  class GenerationImpossibleError < StandardError; end

  PROFILE_ID = "urn:cen.eu:en16931:2017"
  BUSINESS_PROCESS_ID = "S1"
  DOCUMENT_TYPE_CODE = "381" # 381 = avoir / note de crédit (UNTDID 1001)
  DEFAULT_UNIT_CODE = "C62" # C62 = unité
  ZERO_AMOUNT = "0.00"

  def initialize(avoir:)
    @avoir = avoir
    @organisation = avoir.organisation
    @client = avoir.client
    @facture = avoir.facture
    @lignes = avoir.lignes_avoir.order(:position)
  end

  def call
    verifier_avoir_generable!

    Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
      xml["rsm"].CrossIndustryInvoice(namespaces) do
        contexte_document(xml)
        document(xml)
        transaction(xml)
      end
    end.to_xml
  end

  private

  def namespaces
    {
      "xmlns:rsm" => "urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100",
      "xmlns:ram" => "urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100",
      "xmlns:qdt" => "urn:un:unece:uncefact:data:standard:QualifiedDataType:100",
      "xmlns:udt" => "urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100",
      "xmlns:xs" => "http://www.w3.org/2001/XMLSchema"
    }
  end

  def verifier_avoir_generable!
    raise GenerationImpossibleError, "L'avoir est introuvable" if @avoir.blank?
    raise GenerationImpossibleError, "L'avoir doit être émis" unless @avoir.statut == "emise"
    raise GenerationImpossibleError, "L'avoir doit avoir un numéro" if @avoir.numero.blank?
    raise GenerationImpossibleError, "L'avoir doit avoir une date d'émission" if @avoir.date_emission.blank?
    raise GenerationImpossibleError, "L'avoir doit avoir un client" if @client.blank?
    raise GenerationImpossibleError, "L'avoir doit avoir au moins une ligne" if @lignes.empty?
    raise GenerationImpossibleError, "L'avoir doit référencer une facture" if @facture.blank?
    raise GenerationImpossibleError, "La facture référencée doit avoir un numéro (BT-25)" if @facture.numero.blank?
  end

  def contexte_document(xml)
    xml["rsm"].ExchangedDocumentContext do
      xml["ram"].BusinessProcessSpecifiedDocumentContextParameter do
        xml["ram"].ID BUSINESS_PROCESS_ID
      end

      xml["ram"].GuidelineSpecifiedDocumentContextParameter do
        xml["ram"].ID PROFILE_ID
      end
    end
  end

  def document(xml)
    xml["rsm"].ExchangedDocument do
      xml["ram"].ID @avoir.numero
      xml["ram"].TypeCode DOCUMENT_TYPE_CODE

      xml["ram"].IssueDateTime do
        xml["udt"].DateTimeString format_date(@avoir.date_emission), format: "102"
      end

      notes_document.each do |note|
        xml["ram"].IncludedNote do
          xml["ram"].Content note
        end
      end
    end
  end

  def transaction(xml)
    xml["rsm"].SupplyChainTradeTransaction do
      @lignes.each do |ligne|
        ligne_avoir(xml, ligne)
      end

      accord_commercial(xml)
      livraison(xml)
      reglement(xml)
    end
  end

  def ligne_avoir(xml, ligne)
    xml["ram"].IncludedSupplyChainTradeLineItem do
      xml["ram"].AssociatedDocumentLineDocument do
        xml["ram"].LineID ligne_id(ligne)
      end

      xml["ram"].SpecifiedTradeProduct do
        xml["ram"].Name ligne.designation
      end

      xml["ram"].SpecifiedLineTradeAgreement do
        xml["ram"].NetPriceProductTradePrice do
          xml["ram"].ChargeAmount format_montant(ligne.prix_unitaire_ht)
        end
      end

      xml["ram"].SpecifiedLineTradeDelivery do
        xml["ram"].BilledQuantity format_quantite(ligne.quantite), unitCode: DEFAULT_UNIT_CODE
      end

      xml["ram"].SpecifiedLineTradeSettlement do
        xml["ram"].ApplicableTradeTax do
          xml["ram"].TypeCode "VAT"
          xml["ram"].CategoryCode categorie_tva(ligne)
          xml["ram"].RateApplicablePercent format_montant(ligne.taux_tva)

          if categorie_tva(ligne) == "E"
            xml["ram"].ExemptionReason mention_exoneration
          end
        end

        xml["ram"].SpecifiedTradeSettlementLineMonetarySummation do
          xml["ram"].LineTotalAmount format_montant(ligne.total_ht)
        end
      end
    end
  end

  # Pas de BuyerReference : Avoir ne porte pas de référence acheteur propre
  # (contrairement à Facture, cf. reference_acheteur) — l'avoir hérite du
  # contexte commercial de la facture corrigée, référencée via BT-25 (§ reglement).
  def accord_commercial(xml)
    xml["ram"].ApplicableHeaderTradeAgreement do
      vendeur(xml)
      acheteur(xml)
    end
  end

  def vendeur(xml)
    xml["ram"].SellerTradeParty do
      xml["ram"].GlobalID valeur(@organisation, :siret), schemeID: "0009"

      xml["ram"].Name valeur(@organisation, :raison_sociale)

      xml["ram"].SpecifiedLegalOrganization do
        xml["ram"].ID siren_vendeur, schemeID: "0002"
      end

      contact_vendeur(xml)

      adresse(xml, @organisation)

      if valeur(@organisation, :email).present?
        xml["ram"].URIUniversalCommunication do
          xml["ram"].URIID valeur(@organisation, :email), schemeID: "EM"
        end
      end

      if numero_tva_vendeur_a_afficher?
        xml["ram"].SpecifiedTaxRegistration do
          xml["ram"].ID valeur(@organisation, :numero_tva), schemeID: "VA"
        end
      end
    end
  end

  def acheteur(xml)
    xml["ram"].BuyerTradeParty do
      xml["ram"].Name valeur(@client, :raison_sociale)

      if valeur(@client, :siret).present?
        xml["ram"].SpecifiedLegalOrganization do
          xml["ram"].ID valeur(@client, :siret),
                        schemeID: scheme_id_identifiant_legal(valeur(@client, :siret))
        end
      end

      adresse(xml, @client)

      if valeur(@client, :email).present?
        xml["ram"].URIUniversalCommunication do
          xml["ram"].URIID valeur(@client, :email), schemeID: "EM"
        end
      end

      if valeur(@client, :numero_tva).present?
        xml["ram"].SpecifiedTaxRegistration do
          xml["ram"].ID valeur(@client, :numero_tva), schemeID: "VA"
        end
      end
    end
  end

  def contact_vendeur(xml)
    return if valeur(@organisation, :email).blank?

    xml["ram"].DefinedTradeContact do
      xml["ram"].PersonName "Service Facturation"

      xml["ram"].EmailURIUniversalCommunication do
        xml["ram"].URIID valeur(@organisation, :email), schemeID: "SMTP"
      end
    end
  end

  def livraison(xml)
    xml["ram"].ApplicableHeaderTradeDelivery do
      xml["ram"].ActualDeliverySupplyChainEvent do
        xml["ram"].OccurrenceDateTime do
          xml["udt"].DateTimeString format_date(@avoir.date_emission), format: "102"
        end
      end
    end
  end

  # BT-25 (§1 du prompt) : ram:InvoiceReferencedDocument est déclaré dans
  # HeaderTradeSettlementType (XSD ReusableAggregateBusinessInformationEntity,
  # ligne ~86), PAS dans HeaderTradeAgreementType — sa position normée dans la
  # séquence est donc ICI, dans ApplicableHeaderTradeSettlement, APRÈS
  # SpecifiedTradeSettlementHeaderMonetarySummation (seul
  # ReceivableSpecifiedTradeAccountingAccord, non émis, le suit). Vérifié en
  # lisant le XSD vendoré avant d'écrire ce code (§2.B du prompt).
  #
  # Pas de SpecifiedTradeSettlementPaymentMeans (IBAN) ni de
  # SpecifiedTradePaymentTerms : un avoir crédite, il ne réclame pas de
  # paiement — ces blocs n'ont pas de sens pour une note de crédit et sont
  # optionnels dans le XSD (minOccurs="0").
  def reglement(xml)
    xml["ram"].ApplicableHeaderTradeSettlement do
      xml["ram"].InvoiceCurrencyCode devise

      groupes_tva.each_value do |groupe|
        taxe_entete(xml, groupe)
      end

      totaux = totaux_calcules

      xml["ram"].SpecifiedTradeSettlementHeaderMonetarySummation do
        xml["ram"].LineTotalAmount format_montant(totaux.total_ht)
        xml["ram"].ChargeTotalAmount ZERO_AMOUNT
        xml["ram"].AllowanceTotalAmount ZERO_AMOUNT
        xml["ram"].TaxBasisTotalAmount format_montant(totaux.total_ht)
        xml["ram"].TaxTotalAmount format_montant(totaux.total_tva), currencyID: devise
        xml["ram"].GrandTotalAmount format_montant(totaux.total_ttc)
        xml["ram"].DuePayableAmount format_montant(totaux.total_ttc)
      end

      xml["ram"].InvoiceReferencedDocument do
        xml["ram"].IssuerAssignedID @facture.numero
      end
    end
  end

  def taxe_entete(xml, groupe)
    xml["ram"].ApplicableTradeTax do
      xml["ram"].CalculatedAmount format_montant(groupe[:montant_tva])
      xml["ram"].TypeCode "VAT"
      xml["ram"].BasisAmount format_montant(groupe[:base_ht])
      xml["ram"].CategoryCode groupe[:categorie]
      xml["ram"].RateApplicablePercent format_montant(groupe[:taux])

      if groupe[:categorie] == "E"
        xml["ram"].ExemptionReason mention_exoneration
      end
    end
  end

  def adresse(xml, tiers)
    xml["ram"].PostalTradeAddress do
      xml["ram"].PostcodeCode valeur(tiers, :code_postal)
      xml["ram"].LineOne valeur(tiers, :adresse_ligne1)
      xml["ram"].CityName valeur(tiers, :ville)
      xml["ram"].CountryID valeur(tiers, :pays).presence || "FR"
    end
  end

  def notes_document
    notes = []

    notes << @organisation.mentions_legales if @organisation.mentions_legales.present?
    notes << mention_exoneration if franchise_tva?
    notes << "Avoir électronique émis au format Factur-X (profil EN 16931), en référence à la facture #{@facture.numero}."

    notes.compact_blank.uniq
  end

  def mention_exoneration
    "TVA non applicable, art. 293 B du CGI"
  end

  def franchise_tva?
    BigDecimal(totaux_calcules.total_tva.to_s).zero?
  end

  def numero_tva_vendeur_a_afficher?
    valeur(@organisation, :numero_tva).present? && !franchise_tva?
  end

  def devise
    @facture.devise
  end

  def groupes_tva
    totaux_calcules.groupes_tva
  end

  def totaux_calcules
    @totaux_calcules ||= AvoirTotalsService.new(avoir: @avoir).call
  end

  def categorie_tva(ligne)
    taux = BigDecimal(ligne.taux_tva.to_s)

    return "E" if taux.zero?

    "S"
  end

  def ligne_id(ligne)
    position = ligne.position.to_i

    return position.to_s if position.positive?

    (@lignes.index(ligne) + 1).to_s
  end

  def scheme_id_identifiant_legal(identifiant)
    identifiant_normalise = identifiant.to_s.gsub(/\D/, "")

    return "0002" if identifiant_normalise.length == 9
    return "0009" if identifiant_normalise.length == 14

    "0009"
  end

  def siren_vendeur
    valeur(@organisation, :siret).to_s.first(9)
  end

  def format_date(date)
    date.strftime("%Y%m%d")
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
