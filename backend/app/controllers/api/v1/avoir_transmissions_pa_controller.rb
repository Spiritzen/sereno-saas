# frozen_string_literal: true

# V1.2c — miroir de Api::V1::TransmissionsPaController, adapté à l'avoir.
# Le couloir (TransmissionPaOrchestrationService / PaStatusIngestionService)
# est désormais agnostique au type de document (cf. leurs propres
# commentaires) : ce contrôleur l'appelle avec document: @avoir, exactement
# comme le contrôleur facture l'appelle avec facture: @facture — même
# service, même règles, même 5 résultats possibles, jamais dupliqués.
class Api::V1::AvoirTransmissionsPaController < Api::V1::BaseController
  before_action :set_avoir

  def index
    authorize @avoir, :transmissions?

    transmissions = @avoir.transmissions_pa.order(created_at: :desc)

    render json: TransmissionPaBlueprint.render(transmissions), status: :ok
  end

  def create
    authorize @avoir, :transmettre?

    service = TransmissionPaOrchestrationService.new(
      document: @avoir,
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

  def synchroniser
    authorize @avoir, :synchroniser?

    resultat = PaStatusIngestionService.new(document: @avoir).call

    render json: {
      resultat: resultat.resultat,
      motif: resultat.motif,
      statut_facture_avant: resultat.statut_facture_avant,
      statut_facture_apres: resultat.statut_facture_apres,
      transmission: JSON.parse(TransmissionPaBlueprint.render(resultat.transmission))
    }, status: :ok
  rescue PaStatusIngestionService::NonEligibleError => e
    render json: {
      error: "Synchronisation impossible",
      details: e.details
    }, status: :unprocessable_entity
  rescue Pa::NetworkError => e
    render json: {
      error: "Échec technique de la synchronisation",
      details: [ e.message ]
    }, status: :bad_gateway
  end

  private

  def set_avoir
    @avoir = policy_scope(Avoir).find(params[:avoir_id])
  end
end
