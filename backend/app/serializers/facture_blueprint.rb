# frozen_string_literal: true

class FactureBlueprint < Blueprinter::Base
  identifier :id

  # montant_paye n'est PAS exposé ici (paiements v1, étage A, 31/07/2026) :
  # la colonne reste en base à 0 en permanence (lue par le moteur GELÉ
  # factur_x_xml_service.rb pour BT-113/BT-115, jamais mutée) — l'exposer
  # laisserait croire qu'elle reflète les paiements réels. Le "payé" / "reste
  # à payer" réels sont DÉRIVÉS par PaiementSyntheseService.

  fields :client_id,
         :devis_id,
         :numero,
         :type_document,
         :statut,
         :total_ht,
         :total_tva,
         :total_ttc,
         :devise,
         :format,
         :mentions,
         :conditions_paiement,
         :pdf_url,
         :xml_url

  field :date_emission do |facture|
    facture.date_emission&.iso8601
  end

  field :date_echeance do |facture|
    facture.date_echeance&.iso8601
  end

  field :emise_at do |facture|
    facture.emise_at&.iso8601
  end

  field :created_at do |facture|
    facture.created_at&.iso8601
  end

  field :updated_at do |facture|
    facture.updated_at&.iso8601
  end

  field :lignes_count do |facture|
    if facture.association(:lignes_facture).loaded?
      facture.lignes_facture.size
    else
      facture.lignes_facture.count
    end
  end

  view :with_lignes do
    association :lignes_facture, blueprint: LigneFactureBlueprint
  end

  view :with_details do
    association :client, blueprint: ClientBlueprint
    association :lignes_facture, blueprint: LigneFactureBlueprint
  end
end
