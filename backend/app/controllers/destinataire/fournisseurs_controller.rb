# frozen_string_literal: true

module Destinataire
  # Espace client — sidebar "Mes fournisseurs"
  # (execution_espace_client_sidebar_pagination_badge.txt §2). Vue agrégée
  # SIMPLE (raison_sociale + nombre de factures), volontairement NON
  # paginée : la cardinalité de fournisseurs distincts d'un destinataire
  # est structurellement faible, sans rapport avec le volume de factures
  # (qui, lui, est paginé côté Destinataire::FacturesController). Dérivée
  # du MÊME scope isolé — jamais dupliqué autrement qu'à l'identique, même
  # discipline que chemin_archive déjà répété entre contrôleurs destinataire/
  # portail/api plutôt qu'extrait en concern pour une poignée de lignes.
  class FournisseursController < Destinataire::BaseController
    def index
      compteurs = factures_du_scope.group(:organisation_id).count
      organisations_par_id = Organisation.where(id: compteurs.keys).index_by(&:id)

      resultat = compteurs.map do |organisation_id, nombre_factures|
        organisation = organisations_par_id.fetch(organisation_id)

        {
          fournisseur: JSON.parse(PortailOrganisationBlueprint.render(organisation)),
          nombre_factures: nombre_factures
        }
      end.sort_by { |entree| entree[:fournisseur]["raison_sociale"] }

      render json: resultat, status: :ok
    end

    private

    # Identique à Destinataire::FacturesController#factures_du_scope (§1
    # execution_espace_client_etape_b.txt) : périmètre EXCLUSIVEMENT dérivé
    # de client_ids_revendiques, brouillons toujours exclus.
    def factures_du_scope
      Facture.where(client_id: Current.compte_destinataire.client_ids_revendiques)
             .where.not(statut: "brouillon")
    end
  end
end
