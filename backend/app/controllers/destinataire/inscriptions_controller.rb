# frozen_string_literal: true

module Destinataire
  # Création du compte destinataire — SEUL point d'entrée : depuis un lien
  # de portail actif (§1.4 execution_espace_client_etape_a.txt). Le token
  # PROUVE le premier rattachement ; jamais de client_id/organisation_id
  # fourni par l'appelant.
  class InscriptionsController < Destinataire::BaseController
    skip_before_action :authenticate_destinataire!, only: [ :create ]

    def create
      return render_lien_invalide if portail_token.blank?
      return render_compte_existant if CompteDestinataire.exists?(email: email_normalise)

      compte = CompteDestinataire.new(email: params[:email])

      begin
        compte.definir_mot_de_passe(params[:mot_de_passe])
      rescue ArgumentError => e
        return render json: { error: e.message }, status: :unprocessable_entity
      end

      facture = portail_token.facture

      ActiveRecord::Base.transaction do
        compte.save!
        DestinataireClientLink.create!(
          compte_destinataire: compte,
          client: facture.client,
          cree_via: "lien_portail",
          facture_id_preuve: facture.id
        )
      end

      emettre_session_destinataire!(compte)

      render json: { email: compte.email, fournisseurs_lies: 1 }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: "Validation échouée", details: e.record.errors.full_messages }, status: :unprocessable_entity
    end

    private

    def portail_token
      @portail_token ||= PortailFactureToken.resoudre(params[:token])
    end

    def email_normalise
      params[:email].to_s.strip.downcase
    end

    # Message générique — même discipline que Portail::FacturesController :
    # un token inconnu/expiré/révoqué produit la MÊME réponse, jamais de
    # distinction exploitable.
    def render_lien_invalide
      render json: { error: "Lien invalide ou expiré" }, status: :unprocessable_entity
    end

    # Ici, à la différence de la connexion, révéler « un compte existe déjà »
    # est le comportement voulu et sûr (UX d'inscription standard) — pas une
    # énumération de comptes tiers, l'appelant vient de saisir CET e-mail lui-même.
    def render_compte_existant
      render json: { error: "Un compte existe déjà avec cet e-mail — connectez-vous." },
             status: :unprocessable_entity
    end
  end
end
