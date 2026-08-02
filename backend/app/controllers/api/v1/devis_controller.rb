# frozen_string_literal: true

# Miroir de Api::V1::AvoirsController / FacturesController, adapté au cycle
# de vie devis (brouillon -> envoye -> accepte/refuse, converti via
# DevisConversionService). Routes À PLAT (décision Sébastien), comme les
# avoirs.
#
# Pas de journal à la création (contrairement à FacturesController/
# AvoirsController) : logger "devis_cree" bloquerait la suppression d'un
# brouillon fraîchement créé via l'API (evenements_devis est en
# dependent: :restrict_with_exception, comme ses pairs — un événement
# existant empêcherait le destroy). Seules les transitions et la conversion,
# qui SONT la trace utile d'un devis, sont journalisées (étage A + ce
# service).
class Api::V1::DevisController < Api::V1::BaseController
  before_action :set_devis, only: [ :show, :update, :destroy, :envoyer, :accepter, :refuser, :convertir ]

  def index
    devis = policy_scope(Devis).includes(:client, :factures).order(created_at: :desc)
    devis = devis.where(statut: params[:statut]) if params[:statut].present?
    devis = devis.where(client_id: params[:client_id]) if params[:client_id].present?

    render json: DevisBlueprint.render(devis), status: :ok
  end

  def show
    authorize @devis

    render json: DevisBlueprint.render(@devis, view: :with_details), status: :ok
  end

  def create
    attributes = devis_params.to_h.symbolize_keys
    client_id = attributes.delete(:client_id)

    return render json: { error: "client_id est obligatoire" }, status: :unprocessable_entity if client_id.blank?

    client = policy_scope(Client).find(client_id)

    devis = Current.organisation.devis.new(default_devis_attributes.merge(attributes))
    devis.client = client

    authorize devis

    if devis.save
      render json: DevisBlueprint.render(devis, view: :with_details), status: :created
    else
      render_validation_errors(devis)
    end
  end

  def update
    authorize @devis

    attributes = devis_params.to_h.symbolize_keys
    client_id = attributes.delete(:client_id)

    @devis.client = policy_scope(Client).find(client_id) if client_id.present?
    @devis.assign_attributes(attributes)

    if @devis.save
      render json: DevisBlueprint.render(@devis, view: :with_details), status: :ok
    else
      render_validation_errors(@devis)
    end
  end

  def destroy
    authorize @devis

    @devis.destroy!

    head :no_content
  rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey
    render json: {
      error: "Suppression impossible",
      details: [ "Ce devis n'est plus au statut brouillon, ou est lié à des documents métier." ]
    }, status: :unprocessable_entity
  end

  def envoyer
    authorize @devis, :envoyer?

    devis_envoye = DevisStatutService.new(devis: @devis, utilisateur: Current.utilisateur).envoyer!

    render json: DevisBlueprint.render(devis_envoye.reload, view: :with_details), status: :ok
  rescue DevisStatutService::TransitionInterditeError => e
    render json: { error: "Transition impossible", details: [ e.message ] }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render_validation_errors(e.record)
  end

  def accepter
    authorize @devis, :accepter?

    devis_accepte = DevisStatutService.new(devis: @devis, utilisateur: Current.utilisateur).accepter!

    render json: DevisBlueprint.render(devis_accepte.reload, view: :with_details), status: :ok
  rescue DevisStatutService::TransitionInterditeError => e
    render json: { error: "Transition impossible", details: [ e.message ] }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render_validation_errors(e.record)
  end

  def refuser
    authorize @devis, :refuser?

    devis_refuse = DevisStatutService.new(devis: @devis, utilisateur: Current.utilisateur).refuser!

    render json: DevisBlueprint.render(devis_refuse.reload, view: :with_details), status: :ok
  rescue DevisStatutService::TransitionInterditeError => e
    render json: { error: "Transition impossible", details: [ e.message ] }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render_validation_errors(e.record)
  end

  def convertir
    authorize @devis, :convertir?

    facture = DevisConversionService.new(devis: @devis, utilisateur: Current.utilisateur).call

    render json: FactureBlueprint.render(facture.reload, view: :with_details), status: :ok
  rescue DevisConversionService::ConversionImpossibleError => e
    render json: { error: "Conversion impossible", details: e.details }, status: :unprocessable_entity
  rescue FactureEmissionService::EmissionImpossibleError => e
    render json: { error: "Émission impossible", details: e.details }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render_validation_errors(e.record)
  end

  private

  def set_devis
    @devis = policy_scope(Devis).find(params[:id])
  end

  def default_devis_attributes
    {
      statut: "brouillon",
      total_ht: 0,
      total_tva: 0,
      total_ttc: 0
    }
  end

  def devis_params
    params.require(:devis).permit(:client_id, :objet, :date_emission, :date_validite, :conditions)
  end
end
