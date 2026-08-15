# frozen_string_literal: true

module Destinataire
  # Identité minimale du compte connecté — AUCUNE donnée de facture ici,
  # c'est l'étape B (§6 execution_espace_client_etape_a.txt).
  class MoiController < Destinataire::BaseController
    def show
      render json: {
        email: Current.compte_destinataire.email,
        fournisseurs_lies: Current.compte_destinataire.client_ids_revendiques.size
      }, status: :ok
    end
  end
end
