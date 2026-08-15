# frozen_string_literal: true

module Destinataire
  # Ajouter un fournisseur supplémentaire — même preuve que l'inscription
  # (un token de portail actif), jamais une correspondance d'e-mail
  # (§1.4/§5 execution_espace_client_etape_a.txt). Idempotent : revendiquer
  # deux fois le même client ne crée pas de doublon.
  class LiensController < Destinataire::BaseController
    def create
      token = PortailFactureToken.resoudre(params[:token])
      return render_lien_invalide if token.blank?

      facture = token.facture
      client = facture.client

      lien_existant = Current.compte_destinataire.destinataire_client_links.find_by(client_id: client.id)

      if lien_existant
        return render json: { client_id: client.id, deja_lie: true }, status: :ok
      end

      lien = Current.compte_destinataire.destinataire_client_links.create!(
        client: client,
        cree_via: "lien_portail",
        facture_id_preuve: facture.id
      )

      render json: { client_id: lien.client_id, deja_lie: false }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: "Validation échouée", details: e.record.errors.full_messages }, status: :unprocessable_entity
    end

    private

    def render_lien_invalide
      render json: { error: "Lien invalide ou expiré" }, status: :unprocessable_entity
    end
  end
end
