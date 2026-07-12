# frozen_string_literal: true

class Api::V1::TransmissionsPaController < Api::V1::BaseController
  before_action :set_facture

  def index
    authorize @facture, :transmissions?

    transmissions = @facture.transmissions_pa.order(created_at: :desc)

    render json: TransmissionPaBlueprint.render(transmissions), status: :ok
  end

  def create
    authorize @facture, :transmettre?

    service = TransmissionPaOrchestrationService.new(
      facture: @facture,
      utilisateur: Current.utilisateur
    )

    transmission = service.call

    status = service.idempotent_hit? ? :ok : :created

    render json: TransmissionPaBlueprint.render(transmission), status: status
  rescue TransmissionPaOrchestrationService::NonEligibleError => e
    render json: {
      error: "Transmission impossible",
      details: e.details
    }, status: :unprocessable_entity
  rescue TransmissionPaOrchestrationService::TransmissionEchoueeError => e
    render json: {
      error: "Échec technique de la transmission",
      transmission: JSON.parse(TransmissionPaBlueprint.render(e.transmission))
    }, status: :bad_gateway
  end

  private

  def set_facture
    @facture = policy_scope(Facture).find(params[:facture_id])
  end
end
