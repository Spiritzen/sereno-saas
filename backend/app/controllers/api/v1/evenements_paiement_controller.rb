# frozen_string_literal: true

# Miroir de Api::V1::EvenementsAvoirController, niché sous
# factures/:facture_id/paiements/:paiement_id/evenements.
class Api::V1::EvenementsPaiementController < Api::V1::BaseController
  before_action :set_paiement

  def index
    authorize @paiement, :evenements?

    evenements = @paiement.evenements_paiement
                           .includes(:utilisateur)
                           .order(created_at: :asc, id: :asc)

    render json: EvenementPaiementBlueprint.render(evenements), status: :ok
  end

  private

  def set_paiement
    @paiement = policy_scope(Paiement).where(facture_id: params[:facture_id]).find(params[:paiement_id])
  end
end
