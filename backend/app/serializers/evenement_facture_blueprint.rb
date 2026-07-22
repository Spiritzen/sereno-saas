# frozen_string_literal: true

class EvenementFactureBlueprint < Blueprinter::Base
  DETAILS_WHITELIST = {
    "brouillon" => %w[action],
    "emise" => %w[action numero date_emission emise_at]
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
