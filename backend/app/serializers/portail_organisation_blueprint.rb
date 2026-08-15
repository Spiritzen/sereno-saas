# frozen_string_literal: true

# Espace client — Étape B (16/08/2026) — identité MINIMALE du fournisseur,
# vue PUBLIQUE côté destinataire (liste + détail d'une facture). STRICTEMENT
# raison_sociale + logo (seul champ de branding non sensible) — RIEN d'autre.
# EXCLUS délibérément (cf. §0-A execution_espace_client_etape_b.txt) :
# :email, :telephone, :iban (RIB), :identifiant_pa (détail de transmission
# interne), :regime_tva/:fait_generateur_tva (comptable interne),
# :siret/:numero_tva/:adresse*/:mentions_legales (mentions légales internes,
# hors périmètre d'un simple affichage "qui est mon fournisseur").
class PortailOrganisationBlueprint < Blueprinter::Base
  identifier :id

  fields :raison_sociale

  field :logo_url do |organisation|
    organisation.logo_url.presence
  end
end
