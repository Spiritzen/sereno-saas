# frozen_string_literal: true

class Api::V1::ClientsController < Api::V1::BaseController
  before_action :set_client, only: [ :show, :update, :archive, :destroy ]

  def index
    clients = policy_scope(Client)
              .order(:raison_sociale)

    clients = clients.where(statut: params[:statut]) if params[:statut].present?

    render json: ClientBlueprint.render(clients), status: :ok
  end

  def show
    authorize @client

    render json: ClientBlueprint.render(@client, view: :with_contacts), status: :ok
  end

  def create
    client = Current.organisation.clients.new(client_params)

    authorize client

    if client.save
      render json: ClientBlueprint.render(client, view: :with_contacts), status: :created
    else
      render_validation_errors(client)
    end
  end

  def update
    authorize @client

    if @client.update(client_params)
      render json: ClientBlueprint.render(@client, view: :with_contacts), status: :ok
    else
      render_validation_errors(@client)
    end
  end

  def archive
    authorize @client, :archive?

    if @client.update(statut: "archive")
      render json: ClientBlueprint.render(@client, view: :with_contacts), status: :ok
    else
      render_validation_errors(@client)
    end
  end

  def destroy
    authorize @client

    @client.destroy!

    head :no_content
  rescue ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey
    render json: {
      error: "Suppression impossible",
      details: [ "Ce client est lié à des documents métier. Utilisez l'archivage." ]
    }, status: :unprocessable_entity
  end

  private

  def set_client
    @client = policy_scope(Client).find(params[:id])
  end

  def client_params
    params.require(:client).permit(
      :type,
      :raison_sociale,
      :siret,
      :numero_tva,
      :adresse_ligne1,
      :adresse_ligne2,
      :code_postal,
      :ville,
      :pays,
      :email,
      :telephone,
      :identifiant_routage_pa,
      :statut,
      :notes
    )
  end
end
