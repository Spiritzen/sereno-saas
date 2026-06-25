# frozen_string_literal: true

class ContactBlueprint < Blueprinter::Base
  identifier :id

  fields :client_id,
         :nom,
         :prenom,
         :fonction,
         :email,
         :telephone,
         :principal

  field :created_at do |contact|
    contact.created_at&.iso8601
  end

  field :updated_at do |contact|
    contact.updated_at&.iso8601
  end
end