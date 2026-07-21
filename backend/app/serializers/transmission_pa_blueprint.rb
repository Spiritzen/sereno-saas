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

  # V1.1-B3.1b — le strict nécessaire pour que l'UI affiche la prochaine
  # vérification automatique et l'état pause/stop (§9). Pas de compteur
  # d'erreurs ni d'historique de polling ici : panneau de supervision
  # complet = B3.2.
  field :next_poll_at do |transmission|
    transmission.next_poll_at&.iso8601
  end

  field :polling_paused do |transmission|
    transmission.polling_paused_at.present?
  end

  field :polling_stopped do |transmission|
    transmission.polling_stopped_at.present?
  end

  field :polling_stop_reason do |transmission|
    transmission.polling_stop_reason
  end
end
