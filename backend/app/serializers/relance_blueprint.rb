# frozen_string_literal: true

class RelanceBlueprint < Blueprinter::Base
  identifier :id

  # utilisateur_id n'est PAS exposé (même discipline que PaiementBlueprint
  # sur evenement_paiement.utilisateur : ne jamais laisser fuiter un email
  # d'acteur interne via un champ superflu). Le front n'a besoin que de la
  # confirmation de l'acte, pas de son auteur.
  fields :facture_id,
         :canal,
         :statut,
         :destinataire_email,
         :objet,
         :mode_livraison

  field :envoyee_at do |relance|
    relance.envoyee_at&.iso8601
  end

  field :created_at do |relance|
    relance.created_at&.iso8601
  end
end
