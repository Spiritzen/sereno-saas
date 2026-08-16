# frozen_string_literal: true

module Destinataire
  # Espace client — Étape B (16/08/2026) — API LECTURE SEULE des factures du
  # destinataire connecté.
  #
  # ⚠️ INVARIANT DE SÉCURITÉ (§1 execution_espace_client_etape_b.txt), NON
  # négociable : TOUT accès (liste, détail, PDF) est filtré par
  # Current.compte_destinataire.client_ids_revendiques — dérivé EXCLUSIVEMENT
  # de la table de liaison (DestinataireClientLink, posée par preuve à
  # l'étape A). JAMAIS un id de facture/client/organisation fourni par
  # l'appelant n'entre dans ce scope ; JAMAIS Current.organisation (qui
  # n'existe pas dans ce chemin) ; JAMAIS policy_scope de l'app (qui dépend
  # de l'organisation). Un id hors scope renvoie 404 GÉNÉRIQUE — jamais 403,
  # jamais un détail qui révélerait que la facture existe ailleurs (même
  # discipline anti-énumération que Portail::FacturesController).
  class FacturesController < Destinataire::BaseController
    TRIS_AUTORISES = {
      "date_desc" => { date_emission: :desc },
      "date_asc" => { date_emission: :asc },
      "montant_desc" => { total_ttc: :desc },
      "montant_asc" => { total_ttc: :asc }
    }.freeze
    TRI_DEFAUT = "date_desc"

    STATUTS_FILTRABLES = %w[en_attente payee].freeze

    def index
      factures = appliquer_recherche(factures_du_scope.includes(:client, :organisation))
      factures = factures.order(tri_sql).to_a
      factures = appliquer_filtre_statut(factures)

      render json: grouper_par_fournisseur(factures), status: :ok
    end

    def show
      facture = facture_du_scope
      return render_not_found if facture.blank?

      render json: {
        facture: JSON.parse(PortailFactureBlueprint.render(facture)),
        fournisseur: JSON.parse(PortailOrganisationBlueprint.render(facture.organisation)),
        avoirs: JSON.parse(PortailAvoirBlueprint.render(avoirs_emis(facture)))
      }, status: :ok
    end

    def pdf
      facture = facture_du_scope
      return render_not_found if facture.blank?

      chemin_fichier = chemin_archive(facture.pdf_url)

      unless chemin_fichier && File.exist?(chemin_fichier)
        return render json: { error: "PDF indisponible" }, status: :not_found
      end

      send_file chemin_fichier,
                type: "application/pdf",
                disposition: "attachment",
                filename: "facture-#{facture.numero}.pdf"
    end

    private

    # SEULE source du périmètre visible (§1) — dérivée EXCLUSIVEMENT des
    # liens revendiqués. Aucun paramètre appelant n'entre jamais ici.
    #
    # ⚠️ Correctif (16/08/2026) : `where.not(statut: "brouillon")` — même
    # règle déjà appliquée par FecExportService#factures_eligibles et par
    # #avoirs_emis ci-dessous, jamais réinventée ici. Un brouillon est un
    # document interne, jamais émis : le destinataire n'en a jamais eu
    # connaissance, ni via un lien de portail (qui pointe une facture
    # précise) ni autrement. Posé sur le SCOPE DE BASE : protège d'un coup
    # la liste, le détail ET le PDF (un id de brouillon devient
    # structurellement hors scope, 404 générique comme toute facture non
    # revendiquée).
    def factures_du_scope
      Facture.where(client_id: Current.compte_destinataire.client_ids_revendiques)
             .where.not(statut: "brouillon")
    end

    # Résolution PAR ID, mais TOUJOURS bornée au scope : un id hors périmètre
    # renvoie nil ici — jamais un enregistrement d'un client non revendiqué.
    def facture_du_scope
      factures_du_scope.find_by(id: params[:id])
    end

    # Insensible à la casse (ILIKE), sur le numéro de facture ET la raison
    # sociale du FOURNISSEUR (organisations.raison_sociale) — jamais celle
    # du client (le destinataire connaît déjà son propre nom).
    def appliquer_recherche(factures)
      terme = params[:q].to_s.strip
      return factures if terme.blank?

      motif = "%#{terme}%"
      factures.joins(:organisation).where(
        "factures.numero ILIKE :motif OR organisations.raison_sociale ILIKE :motif", motif: motif
      )
    end

    # Filtre appliqué APRÈS chargement : le statut de paiement n'est pas une
    # colonne, il est DÉRIVÉ (PaiementSyntheseService, cf. §0-B) — jamais une
    # 2e formule SQL qui dupliquerait cette dérivation.
    def appliquer_filtre_statut(factures)
      statut_demande = params[:statut]
      return factures unless STATUTS_FILTRABLES.include?(statut_demande)

      factures.select do |facture|
        reste_a_payer = PaiementSyntheseService.new(facture: facture).call.reste_a_payer
        statut_demande == "payee" ? reste_a_payer.zero? : reste_a_payer.positive?
      end
    end

    # WHITELIST stricte — un `tri` inconnu retombe sur le défaut, jamais une
    # interpolation du paramètre brut dans le SQL (aucune injection possible).
    def tri_sql
      TRIS_AUTORISES.fetch(params[:tri], TRIS_AUTORISES.fetch(TRI_DEFAUT))
    end

    def grouper_par_fournisseur(factures)
      factures.group_by(&:organisation).map do |organisation, factures_orga|
        {
          fournisseur: JSON.parse(PortailOrganisationBlueprint.render(organisation)),
          factures: JSON.parse(PortailFactureListeBlueprint.render(factures_orga))
        }
      end
    end

    # Même exclusion que Portail::FacturesController#avoirs : brouillons
    # jamais émis, purement internes.
    def avoirs_emis(facture)
      facture.avoirs.where.not(statut: "brouillon").order(created_at: :desc)
    end

    # Même mécanique que Portail::FacturesController#chemin_archive et
    # Api::V1::FacturesController#chemin_archive — dupliquée à l'identique
    # (même discipline déjà en place entre ces deux-là), jamais de
    # régénération, toujours une lecture d'un fichier déjà archivé.
    def chemin_archive(chemin_relatif)
      return nil if chemin_relatif.blank?

      Rails.root.join(chemin_relatif)
    end
  end
end
