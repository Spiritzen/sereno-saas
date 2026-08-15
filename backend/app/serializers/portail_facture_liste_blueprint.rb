# frozen_string_literal: true

# Espace client — Étape B (16/08/2026) — vue LISTE légère (une ligne de
# tableau « mes factures »), plus fine que PortailFactureBlueprint (détail
# complet) : ni lignes, ni client imbriqué (le fournisseur est déjà porté au
# niveau du groupe par Destinataire::FacturesController#index). Champs
# identiques à ceux déjà jugés publics par PortailFactureBlueprint — jamais
# une 2e décision d'exposition, juste un sous-ensemble plus léger.
class PortailFactureListeBlueprint < Blueprinter::Base
  identifier :id

  fields :numero, :statut, :total_ttc, :devise

  field :date_emission do |facture|
    facture.date_emission&.iso8601
  end

  field :date_echeance do |facture|
    facture.date_echeance&.iso8601
  end

  # DÉRIVÉS via le MÊME PaiementSyntheseService que PortailFactureBlueprint —
  # jamais une 2e formule (cf. §0-B execution_espace_client_etape_b.txt).
  field :reste_a_payer do |facture|
    PaiementSyntheseService.new(facture: facture).call.reste_a_payer
  end

  field :statut_encaissement_local do |facture|
    PaiementSyntheseService.new(facture: facture).call.statut_encaissement_local
  end
end
