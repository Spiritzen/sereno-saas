# frozen_string_literal: true

# Miroir de Api::V1::PaiementsController : toute l'orchestration
# (construction, tentative d'envoi, journalisation append-only) vit dans
# RelanceService — ce contrôleur ne fait qu'appeler, jamais réimplémenter.
class Api::V1::RelancesController < Api::V1::BaseController
  before_action :set_facture, only: [ :create ]

  def create
    relance_pour_autorisation = Relance.new(
      organisation: Current.organisation,
      facture: @facture
    )

    authorize relance_pour_autorisation, :create?

    relance = relance_service.envoyer!(facture: @facture)

    render json: {
      relance: JSON.parse(RelanceBlueprint.render(relance)),
      facture: JSON.parse(FactureBlueprint.render(@facture.reload, view: :with_details))
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_errors(e.record)
  end

  private

  def relance_service
    RelanceService.new(organisation: Current.organisation, utilisateur: Current.utilisateur)
  end

  def set_facture
    @facture = policy_scope(Facture).find(params[:facture_id])
  end
end
