# frozen_string_literal: true

class ClientBlueprint < Blueprinter::Base
  identifier :id

  fields :type,
         :raison_sociale,
         :siret,
         :numero_tva,
         :adresse_ligne1,
         :adresse_ligne2,
         :code_postal,
         :ville,
         :pays,
         :email,
         :telephone,
         :identifiant_routage_pa,
         :statut,
         :notes

  field :contacts_count do |client|
    if client.association(:contacts).loaded?
      client.contacts.size
    else
      client.contacts.count
    end
  end

  field :created_at do |client|
    client.created_at&.iso8601
  end

  field :updated_at do |client|
    client.updated_at&.iso8601
  end

  view :with_contacts do
    association :contacts, blueprint: ContactBlueprint
  end
end