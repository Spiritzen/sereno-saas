# frozen_string_literal: true

class Api::V1::TransmissionsPaController < Api::V1::BaseController
  before_action :set_facture, except: [ :review_count ]

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

  def synchroniser
    authorize @facture, :synchroniser?

    resultat = PaStatusIngestionService.new(facture: @facture).call

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

  def relancer
    authorize @facture, :relancer?

    transmission = PaPollingRelanceService.new(facture: @facture).call

    render json: TransmissionPaBlueprint.render(transmission), status: :ok
  rescue PaPollingRelanceService::NonRelancableError => e
    render json: {
      error: "Relance impossible",
      details: e.details
    }, status: :unprocessable_entity
  end

  # Organisation-scopée : aucune facture précise, donc pas de set_facture ni
  # de policy_scope(Facture) ici. L'isolation tient au fait que le compteur
  # ne lit jamais que Current.organisation (posé par authenticate_request!,
  # cf. Api::V1::BaseController) — même discipline que
  # FacturePolicy::Scope#resolve.
  def review_count
    count = PaRequiresReviewCounter.call(organisation: Current.organisation)

    render json: { requires_review_count: count }, status: :ok
  end

  private

  def set_facture
    @facture = policy_scope(Facture).find(params[:facture_id])
  end
end
