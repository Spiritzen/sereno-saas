# frozen_string_literal: true

class FacturXXmlService
  class GenerationImpossibleError < StandardError; end

  PROFILE_ID = "urn:cen.eu:en16931:2017"
  # Cadre de facturation France CTC (BT-23, BR-FR-08) : "S1" = dépôt d'une
  # facture de prestation de service standard (AFNOR XP Z12-012). Sereno
  # cible les prestataires de services indépendants (pas de vente de biens).
  BUSINESS_PROCESS_ID = "S1"
  DOCUMENT_TYPE_CODE = "380" # 380 = facture commerciale
  PAYMENT_MEANS_TRANSFER_CODE = "58" # 58 = virement SEPA
  DEFAULT_UNIT_CODE = "C62" # C62 = unité
  ZERO_AMOUNT = "0.00"

  # Mentions BT-22 obligatoires (France CTC / Flux2, BR-FR-05).
  MENTION_FRAIS_RECOUVREMENT = "Indemnité forfaitaire pour frais de recouvrement : 40 €."
  MENTION_PENALITES_RETARD = "Pénalités de retard exigibles en cas de paiement après échéance, selon les conditions de paiement applicables."
  MENTION_ESCOMPTE = "Aucun escompte accordé pour paiement anticipé."

  def initialize(facture:)
    @facture = facture
    @organisation = facture.organisation
    @client = facture.client
    @lignes = facture.lignes_facture.order(:position)
  end

  def call
    verifier_facture_generable!

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

  def verifier_facture_generable!
    raise GenerationImpossibleError, "La facture est introuvable" if @facture.blank?
    raise GenerationImpossibleError, "La facture doit être émise" unless @facture.statut == "emise"
    raise GenerationImpossibleError, "La facture doit avoir un numéro" if @facture.numero.blank?
    raise GenerationImpossibleError, "La facture doit avoir une date d'émission" if @facture.date_emission.blank?
    raise GenerationImpossibleError, "La facture doit avoir un client" if @client.blank?
    raise GenerationImpossibleError, "La facture doit avoir au moins une ligne" if @lignes.empty?
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
      xml["ram"].ID @facture.numero
      xml["ram"].TypeCode DOCUMENT_TYPE_CODE

      xml["ram"].IssueDateTime do
        xml["udt"].DateTimeString format_date(@facture.date_emission), format: "102"
      end

      notes_document.each do |note|
        xml["ram"].IncludedNote do
          xml["ram"].Content note
        end
      end

      notes_document_ctc.each do |note|
        xml["ram"].IncludedNote do
          xml["ram"].Content note[:content]
          xml["ram"].SubjectCode note[:subject_code]
        end
      end
    end
  end

  def transaction(xml)
    xml["rsm"].SupplyChainTradeTransaction do
      @lignes.each do |ligne|
        ligne_facture(xml, ligne)
      end

      accord_commercial(xml)
      livraison(xml)
      reglement(xml)
    end
  end

  def ligne_facture(xml, ligne)
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

  def accord_commercial(xml)
    xml["ram"].ApplicableHeaderTradeAgreement do
      if buyer_reference.present?
        xml["ram"].BuyerReference buyer_reference
      end

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
          xml["udt"].DateTimeString format_date(@facture.date_emission), format: "102"
        end
      end
    end
  end

  def reglement(xml)
    xml["ram"].ApplicableHeaderTradeSettlement do
      xml["ram"].InvoiceCurrencyCode @facture.devise

      moyen_paiement(xml)

      groupes_tva.each_value do |groupe|
        taxe_entete(xml, groupe)
      end

      conditions_paiement(xml)

      totaux = totaux_calcules

xml["ram"].SpecifiedTradeSettlementHeaderMonetarySummation do
  xml["ram"].LineTotalAmount format_montant(totaux.total_ht)
  xml["ram"].ChargeTotalAmount ZERO_AMOUNT
  xml["ram"].AllowanceTotalAmount ZERO_AMOUNT
  xml["ram"].TaxBasisTotalAmount format_montant(totaux.total_ht)
  xml["ram"].TaxTotalAmount format_montant(totaux.total_tva), currencyID: @facture.devise
  xml["ram"].GrandTotalAmount format_montant(totaux.total_ttc)
  xml["ram"].TotalPrepaidAmount format_montant(@facture.montant_paye || 0)
  xml["ram"].DuePayableAmount format_montant(montant_restant_a_payer)
end
    end
  end

  def moyen_paiement(xml)
    return if valeur(@organisation, :iban).blank?

    xml["ram"].SpecifiedTradeSettlementPaymentMeans do
      xml["ram"].TypeCode PAYMENT_MEANS_TRANSFER_CODE

      xml["ram"].PayeePartyCreditorFinancialAccount do
        xml["ram"].IBANID valeur(@organisation, :iban)
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

  def conditions_paiement(xml)
    return if @facture.date_echeance.blank? && @facture.conditions_paiement.blank?

    xml["ram"].SpecifiedTradePaymentTerms do
      if @facture.conditions_paiement.present?
        xml["ram"].Description @facture.conditions_paiement
      end

      if @facture.date_echeance.present?
        xml["ram"].DueDateDateTime do
          xml["udt"].DateTimeString format_date(@facture.date_echeance), format: "102"
        end
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

    notes << @facture.mentions if @facture.mentions.present?
    notes << @organisation.mentions_legales if @organisation.mentions_legales.present?
    notes << mention_exoneration if franchise_tva?
    notes << "Facture électronique émise au format Factur-X (profil EN 16931)."

    notes.compact_blank.uniq
  end

  def mention_exoneration
    "TVA non applicable, art. 293 B du CGI"
  end

  def notes_document_ctc
    [
      { content: MENTION_FRAIS_RECOUVREMENT, subject_code: "PMT" },
      { content: MENTION_PENALITES_RETARD, subject_code: "PMD" },
      { content: MENTION_ESCOMPTE, subject_code: "AAB" }
    ]
  end

  def franchise_tva?
  BigDecimal(totaux_calcules.total_tva.to_s).zero?
end

  def numero_tva_vendeur_a_afficher?
    valeur(@organisation, :numero_tva).present? && !franchise_tva?
  end

  def buyer_reference
    return "" unless @facture.respond_to?(:reference_acheteur)

    @facture.reference_acheteur.to_s
  end

def groupes_tva
  totaux_calcules.groupes_tva
end

def totaux_calcules
  @totaux_calcules ||= FactureTotalsService.new(facture: @facture).call
end

  def categorie_tva(ligne)
    taux = BigDecimal(ligne.taux_tva.to_s)

    return "E" if taux.zero?

    "S"
  end

  def montant_restant_a_payer
  total_ttc = BigDecimal(totaux_calcules.total_ttc.to_s)
  montant_paye = BigDecimal((@facture.montant_paye || 0).to_s)

  total_ttc - montant_paye
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
