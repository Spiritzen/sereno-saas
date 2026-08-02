# frozen_string_literal: true

class Api::V1::EvenementsDevisController < Api::V1::BaseController
  before_action :set_devis

  def index
    authorize @devis, :evenements?

    evenements = @devis.evenements_devis
                        .includes(:utilisateur)
                        .order(created_at: :asc, id: :asc)

    render json: EvenementDevisBlueprint.render(evenements), status: :ok
  end

  private

  def set_devis
    @devis = policy_scope(Devis).find(params[:devis_id])
  end
end
