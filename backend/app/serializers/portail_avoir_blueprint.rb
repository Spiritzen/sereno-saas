# frozen_string_literal: true

# Portail destinataire (MVP) — avoirs liés à une facture, vue publique.
# Exclut :pdf_url/:xml_url (chemins de stockage internes — aucun
# téléchargement d'avoir dans ce MVP, hors périmètre) et :client_id/
# :facture_id (IDs internes déjà implicites : ce sont les avoirs DE la
# facture consultée via ce token, jamais d'autres).
class PortailAvoirBlueprint < Blueprinter::Base
  identifier :id

  fields :numero,
         :motif,
         :statut,
         :total_ht,
         :total_tva,
         :total_ttc

  field :date_emission do |avoir|
    avoir.date_emission&.iso8601
  end

  field :emis_at do |avoir|
    avoir.emis_at&.iso8601
  end
end
