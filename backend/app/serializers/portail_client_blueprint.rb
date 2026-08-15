# frozen_string_literal: true

# Portail destinataire (MVP) — identité minimale du client sur une facture
# publique. Volontairement DISTINCT de ClientBlueprint (jamais une simple
# vue "moins quelques champs") : exclut :email/:telephone (inutile de
# renvoyer au client ses propres coordonnées), :notes (interne, jamais
# destiné au client lui-même), :identifiant_routage_pa (détail de
# transmission interne), :statut (actif/archivé — sans pertinence pour un
# tiers), :contacts_count (interne CRM).
class PortailClientBlueprint < Blueprinter::Base
  identifier :id

  fields :type,
         :raison_sociale,
         :siret,
         :numero_tva,
         :adresse_ligne1,
         :adresse_ligne2,
         :code_postal,
         :ville,
         :pays
end
