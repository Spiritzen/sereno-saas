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

    # execution_espace_client_sidebar_pagination_badge.txt §3 — pagination
    # RÉELLE, dans le scope déjà isolé (jamais un simple masquage écran).
    PAR_PAGE = 10

    def index
      factures = appliquer_recherche(factures_du_scope.includes(:client, :organisation))
      factures = appliquer_filtre_fournisseur(factures)
      factures = factures.order(tri_sql).to_a
      factures = appliquer_filtre_statut(factures)

      render json: {
        groupes: grouper_par_fournisseur(paginer(factures)),
        pagination: pagination_meta(factures.size)
      }, status: :ok
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

    # Bonus §2 (sidebar "Mes fournisseurs" -> clic filtrant) — reste borné
    # par factures_du_scope, ne peut donc QUE rétrécir le résultat, jamais
    # l'élargir : un fournisseur_id hors périmètre renvoie simplement une
    # liste vide, jamais une fuite.
    def appliquer_filtre_fournisseur(factures)
      fournisseur_id = params[:fournisseur_id]
      return factures if fournisseur_id.blank?

      factures.where(organisation_id: fournisseur_id)
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

    # Pagination du résultat déjà FILTRÉ/TRIÉ (recherche + statut + tri
    # s'appliquent avant, jamais après — §3) : la page 2 est la suite
    # logique de la page 1 pour les MÊMES critères, jamais une re-pagination
    # d'un jeu différent. Groupement par fournisseur appliqué APRÈS ce
    # découpage (sur les 10 factures de la page), donc une page peut
    # contenir des groupes partiels — assumé, cf. rapport.
    def paginer(factures)
      debut = (page_demandee - 1) * PAR_PAGE
      factures.slice(debut, PAR_PAGE) || []
    end

    def pagination_meta(total)
      {
        page: page_demandee,
        par_page: PAR_PAGE,
        total: total,
        total_pages: (total.to_f / PAR_PAGE).ceil
      }
    end

    # `to_i` neutralise tout paramètre non numérique/malicieux (retombe sur
    # 0, donc sur la page 1) — même discipline que la whitelist de tri,
    # jamais d'interpolation ni de confiance aveugle dans l'entrée utilisateur.
    def page_demandee
      page = params[:page].to_i
      page.positive? ? page : 1
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
