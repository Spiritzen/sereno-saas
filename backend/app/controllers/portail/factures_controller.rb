# frozen_string_literal: true

module Portail
  # Contrôleur PUBLIC (aucune auth JWT) — miroir de Webhooks::PaController :
  # hérite directement d'ApplicationController, JAMAIS de Api::V1::BaseController
  # (donc aucun before_action authenticate_request!, aucun Current.organisation).
  #
  # ⚠️ RÈGLE ABSOLUE (§1 execution_portail_destinataire_mvp.txt) : la facture
  # est TOUJOURS résolue depuis le TOKEN (PortailFactureToken.resoudre),
  # JAMAIS depuis un id/facture_id fourni par l'appelant — aucune action ici
  # ne lit un autre paramètre que :token. C'est ce avant tout qui empêche
  # l'énumération : il n'existe aucun paramètre à faire varier.
  #
  # ⚠️ Lecture seule stricte : aucune écriture ici, le PDF est SERVI
  # (send_file, chemin déjà archivé), jamais régénéré.
  class FacturesController < ApplicationController
    before_action :resoudre_token!

    def show
      render json: PortailFactureBlueprint.render(@facture), status: :ok
    end

    def pdf
      chemin_fichier = chemin_archive(@facture.pdf_url)

      unless chemin_fichier && File.exist?(chemin_fichier)
        return render json: { error: "PDF indisponible" }, status: :not_found
      end

      send_file chemin_fichier,
                type: "application/pdf",
                disposition: "attachment",
                filename: "facture-#{@facture.numero}.pdf"
    end

    def avoirs
      # Scopés PAR LE TOKEN : @facture vient exclusivement de la résolution
      # ci-dessous, jamais d'un paramètre fourni par l'appelant. Les
      # brouillons (jamais émis, purement internes) sont exclus, même
      # discipline que PaiementSyntheseService#somme_avoirs_emis.
      avoirs = @facture.avoirs.where.not(statut: "brouillon").order(created_at: :desc)

      render json: PortailAvoirBlueprint.render(avoirs), status: :ok
    end

    private

    def resoudre_token!
      token = PortailFactureToken.resoudre(params[:token])
      return render_lien_invalide if token.blank?

      @facture = token.facture
    end

    # Message générique, IDENTIQUE quel que soit le cas réel (token inconnu /
    # expiré / révoqué) — aucune fuite exploitable, même discipline que
    # Webhooks::PaController (cf. §1).
    def render_lien_invalide
      render json: { error: "Lien invalide ou expiré" }, status: :not_found
    end

    def chemin_archive(chemin_relatif)
      return nil if chemin_relatif.blank?

      Rails.root.join(chemin_relatif)
    end
  end
end
