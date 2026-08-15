# frozen_string_literal: true

module Destinataire
  # Suppression du compte (RGPD, droit à l'effacement) — confirmée par le
  # mot de passe (pas seulement la session active) : un accès navigateur
  # laissé ouvert ne doit pas suffire à détruire le compte. La cascade
  # (sessions + liens) vit dans les associations du modèle
  # (dependent: :destroy), jamais réimplémentée ici.
  class ComptesController < Destinataire::BaseController
    def destroy
      compte = Current.compte_destinataire

      unless compte.mot_de_passe_valide?(params[:mot_de_passe])
        return render json: { error: "Mot de passe invalide" }, status: :unauthorized
      end

      compte.destroy!

      render json: { message: "Compte supprimé" }, status: :ok
    end
  end
end
