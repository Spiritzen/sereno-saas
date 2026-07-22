# frozen_string_literal: true

class Api::V1::EvenementsFactureController < Api::V1::BaseController
  before_action :set_facture

  def index
    authorize @facture, :evenements?

    evenements = @facture.evenements_facture
                          .includes(:utilisateur)
                          .order(created_at: :asc, id: :asc)

    render json: EvenementFactureBlueprint.render(evenements), status: :ok
  end

  private

  def set_facture
    @facture = policy_scope(Facture).find(params[:facture_id])
  end
end
