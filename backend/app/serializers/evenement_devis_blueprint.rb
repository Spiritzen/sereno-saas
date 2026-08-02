# frozen_string_literal: true

# Miroir de EvenementPaiementBlueprint/EvenementAvoirBlueprint : whitelist du
# payload — mais PAR ACTION plutôt que par statut, contrairement à ses
# précédents. Raison : "devis_converti" (créé par DevisConversionService)
# partage le même `statut` ("accepte") qu'un simple "devis_accepte", mais son
# payload contient des clés différentes (référence facture). Une whitelist
# par statut confondrait les deux formes ; par action, chaque payload garde
# exactement sa forme. Acteur = id + display_name, JAMAIS l'email.
class EvenementDevisBlueprint < Blueprinter::Base
  DETAILS_WHITELIST = {
    "devis_envoye" => %w[action numero],
    "devis_accepte" => %w[action numero],
    "devis_refuse" => %w[action numero],
    "devis_converti" => %w[action facture_id facture_numero]
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
    action = payload["action"]
    allowed_keys = DETAILS_WHITELIST[action] || %w[action]

    payload.slice(*allowed_keys)
  end
end
