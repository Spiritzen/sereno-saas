# frozen_string_literal: true

# Miroir exact de EvenementFactureBlueprint. Whitelist par statut : le
# payload stocké (V1.2a/b) contient pdf_url/xml_url pour l'archivage interne,
# mais l'API ne les expose JAMAIS ici — seuls les champs listés ci-dessous
# passent le filtre, quel que soit le contenu réel du payload.
class EvenementAvoirBlueprint < Blueprinter::Base
  DETAILS_WHITELIST = {
    "brouillon" => %w[action],
    "emise" => %w[action numero date_emission emis_at]
  }.freeze

  identifier :id

  fields :statut, :source, :code_statut_pa

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
    allowed_keys = DETAILS_WHITELIST[evenement.statut] || %w[action]

    payload.slice(*allowed_keys)
  end
end
