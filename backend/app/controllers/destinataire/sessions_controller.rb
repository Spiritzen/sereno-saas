# frozen_string_literal: true

module Destinataire
  class SessionsController < Destinataire::BaseController
    skip_before_action :authenticate_destinataire!, only: [ :create ]

    def create
      compte = CompteDestinataire.find_by(email: params[:email].to_s.strip.downcase)

      unless compte&.mot_de_passe_valide?(params[:mot_de_passe])
        # Générique — jamais distinguer "e-mail inconnu" de "mot de passe
        # faux" (§5 execution_espace_client_etape_a.txt : aucune énumération).
        return render json: { error: "E-mail ou mot de passe invalide" }, status: :unauthorized
      end

      emettre_session_destinataire!(compte)

      render json: { email: compte.email, fournisseurs_lies: compte.client_ids_revendiques.size }, status: :ok
    end

    def destroy
      Current.destinataire_session.revoquer!
      supprimer_cookies_destinataire!

      render json: { message: "Déconnexion réussie" }, status: :ok
    end
  end
end
