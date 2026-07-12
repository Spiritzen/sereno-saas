# frozen_string_literal: true

# Discipline reprise de EvenementFactureBlueprint (déjà validée en audit) :
# on expose le nécessaire pour l'UI, jamais les credentials, jamais le
# payload brut non filtré, jamais les identifiants internes.
class TransmissionPaBlueprint < Blueprinter::Base
  identifier :id

  fields :statut, :tentative, :message_erreur

  field :fournisseur do |transmission|
    transmission.plateforme_agreee.fournisseur
  end

  field :external_id do |transmission|
    transmission.identifiant_pa
  end

  field :transmis_at do |transmission|
    transmission.transmis_at&.iso8601
  end

  field :created_at do |transmission|
    transmission.created_at&.iso8601
  end

  field :simulation do |transmission|
    transmission.plateforme_agreee.fournisseur == "sandbox"
  end
end
