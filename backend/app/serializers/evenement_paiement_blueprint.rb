# frozen_string_literal: true

# Miroir exact de EvenementAvoirBlueprint. Whitelist par statut : le payload
# stocké (PaiementService) contient montant/methode_code/date_encaissement/
# reference pour l'archivage interne, mais l'API n'expose JAMAIS le payload
# brut ici — seuls les champs listés ci-dessous passent le filtre.
class EvenementPaiementBlueprint < Blueprinter::Base
  DETAILS_WHITELIST = {
    "brouillon" => %w[montant methode_code date_encaissement],
    "confirme" => %w[montant methode_code date_encaissement],
    "annule" => %w[montant methode_code date_encaissement]
  }.freeze

  identifier :id

  fields :statut, :source

  field :created_at do |evenement|
    evenement.created_at&.iso8601
  end

  field :actor do |evenement|
    next nil if evenement.utilisateur.blank?

    {
      id: evenement.utilisateur.id,
      display_name: "#{evenement.utilisateur.prenom} #{evenement.utilisateur.nom}".strip
    }
  end

  field :details do |evenement|
    payload = evenement.payload || {}
    allowed_keys = DETAILS_WHITELIST[evenement.statut] || []

    payload.slice(*allowed_keys)
  end
end
