# frozen_string_literal: true

class Api::V1::EvenementsAvoirController < Api::V1::BaseController
  before_action :set_avoir

  def index
    authorize @avoir, :evenements?

    evenements = @avoir.evenements_avoir
                        .includes(:utilisateur)
                        .order(created_at: :asc, id: :asc)

    render json: EvenementAvoirBlueprint.render(evenements), status: :ok
  end

  private

  def set_avoir
    @avoir = policy_scope(Avoir).find(params[:avoir_id])
  end
end
