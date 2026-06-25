# frozen_string_literal: true

class FacturXXmlService
  class GenerationImpossibleError < StandardError; end

  PROFILE_ID = "urn:factur-x.eu:1p0:en16931"
  DOCUMENT_TYPE_CODE = "380" # Commercial invoice

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
      "xmlns:udt" => "urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100"
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
        xml["udt"].DateTimeString @facture.date_emission.strftime("%Y%m%d"), format: "102"
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
        xml["ram"].LineID ligne.position.to_s
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
        xml["ram"].BilledQuantity format_quantite(ligne.quantite), unitCode: "C62"
      end

      xml["ram"].SpecifiedLineTradeSettlement do
        xml["ram"].ApplicableTradeTax do
          xml["ram"].TypeCode "VAT"
          xml["ram"].CategoryCode "S"
          xml["ram"].RateApplicablePercent format_montant(ligne.taux_tva)
        end

        xml["ram"].SpecifiedTradeSettlementLineMonetarySummation do
          xml["ram"].LineTotalAmount format_montant(ligne.total_ht)
        end
      end
    end
  end

  def accord_commercial(xml)
    xml["ram"].ApplicableHeaderTradeAgreement do
      xml["ram"].SellerTradeParty do
        xml["ram"].Name valeur(@organisation, :raison_sociale)

        xml["ram"].SpecifiedLegalOrganization do
          xml["ram"].ID valeur(@organisation, :siret)
        end

        adresse(xml, @organisation)

        if valeur(@organisation, :numero_tva).present?
          xml["ram"].SpecifiedTaxRegistration do
            xml["ram"].ID valeur(@organisation, :numero_tva), schemeID: "VA"
          end
        end
      end

      xml["ram"].BuyerTradeParty do
        xml["ram"].Name valeur(@client, :raison_sociale)

        if valeur(@client, :siret).present?
          xml["ram"].SpecifiedLegalOrganization do
            xml["ram"].ID valeur(@client, :siret)
          end
        end

        adresse(xml, @client)

        if valeur(@client, :numero_tva).present?
          xml["ram"].SpecifiedTaxRegistration do
            xml["ram"].ID valeur(@client, :numero_tva), schemeID: "VA"
          end
        end
      end
    end
  end

  def livraison(xml)
    xml["ram"].ApplicableHeaderTradeDelivery do
      xml["ram"].ActualDeliverySupplyChainEvent do
        xml["ram"].OccurrenceDateTime do
          xml["udt"].DateTimeString @facture.date_emission.strftime("%Y%m%d"), format: "102"
        end
      end
    end
  end

  def reglement(xml)
    xml["ram"].ApplicableHeaderTradeSettlement do
      xml["ram"].InvoiceCurrencyCode @facture.devise

      xml["ram"].ApplicableTradeTax do
        xml["ram"].CalculatedAmount format_montant(@facture.total_tva)
        xml["ram"].TypeCode "VAT"
        xml["ram"].BasisAmount format_montant(@facture.total_ht)
        xml["ram"].CategoryCode "S"
        xml["ram"].RateApplicablePercent taux_tva_principal
      end

      if @facture.conditions_paiement.present?
        xml["ram"].SpecifiedTradePaymentTerms do
          xml["ram"].Description @facture.conditions_paiement
        end
      end

      xml["ram"].SpecifiedTradeSettlementHeaderMonetarySummation do
        xml["ram"].LineTotalAmount format_montant(@facture.total_ht)
        xml["ram"].TaxBasisTotalAmount format_montant(@facture.total_ht)
        xml["ram"].TaxTotalAmount format_montant(@facture.total_tva), currencyID: @facture.devise
        xml["ram"].GrandTotalAmount format_montant(@facture.total_ttc)
        xml["ram"].DuePayableAmount format_montant(@facture.total_ttc)
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

  def taux_tva_principal
    taux = @lignes.first&.taux_tva || 20
    format_montant(taux)
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