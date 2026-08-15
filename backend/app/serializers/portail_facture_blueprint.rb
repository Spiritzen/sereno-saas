# frozen_string_literal: true

# Portail destinataire (MVP) — vue PUBLIQUE d'une facture, volontairement
# DISTINCTE de FactureBlueprint (jamais une vue :with_details "moins
# quelques champs" — chaque champ exposé ici est une décision explicite,
# jamais un oubli d'exclusion). Exclus délibérément :
#   - :client_id / :devis_id (IDs internes, sans usage côté portail) ;
#   - :pdf_url / :xml_url (chemins de STOCKAGE internes — le PDF se
#     télécharge via Portail::FacturesController#pdf, jamais son chemin
#     brut) ;
#   - :relancable / :derniere_relance_at / :relances_count (signaux CRM
#     internes — un tiers n'a pas à savoir qu'il va être relancé).
# `reste_a_payer`/`statut_encaissement_local` restent DÉRIVÉS via le même
# PaiementSyntheseService que FactureBlueprint — jamais un recalcul maison.
class PortailFactureBlueprint < Blueprinter::Base
  identifier :id

  fields :numero,
         :type_document,
         :statut,
         :total_ht,
         :total_tva,
         :total_ttc,
         :devise,
         :mentions,
         :conditions_paiement

  field :date_emission do |facture|
    facture.date_emission&.iso8601
  end

  field :date_echeance do |facture|
    facture.date_echeance&.iso8601
  end

  field :emise_at do |facture|
    facture.emise_at&.iso8601
  end

  field :reste_a_payer do |facture|
    PaiementSyntheseService.new(facture: facture).call.reste_a_payer
  end

  field :statut_encaissement_local do |facture|
    PaiementSyntheseService.new(facture: facture).call.statut_encaissement_local
  end

  # Booléen DÉRIVÉ, jamais le chemin brut (:pdf_url volontairement exclu
  # ci-dessus) : permet au frontend d'afficher/masquer le bouton
  # téléchargement sans jamais connaître la convention de stockage interne.
  field :pdf_disponible do |facture|
    facture.pdf_url.present?
  end

  association :client, blueprint: PortailClientBlueprint
  association :lignes_facture, blueprint: LigneFactureBlueprint
end
