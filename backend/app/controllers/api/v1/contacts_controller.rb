# frozen_string_literal: true

class Api::V1::ContactsController < Api::V1::BaseController
  before_action :set_client, only: [ :index, :create ]
  before_action :set_contact, only: [ :show, :update, :destroy ]

  def index
    contacts = policy_scope(Contact)
               .where(client: @client)
               .order(principal: :desc, nom: :asc, prenom: :asc)

    render json: ContactBlueprint.render(contacts), status: :ok
  end

  def show
    authorize @contact

    render json: ContactBlueprint.render(@contact), status: :ok
  end

  def create
    contact = @client.contacts.new(contact_params)
    contact.organisation = Current.organisation

    authorize contact

    if contact.save
      render json: ContactBlueprint.render(contact), status: :created
    else
      render_validation_errors(contact)
    end
  end

  def update
    authorize @contact

    if @contact.update(contact_params)
      render json: ContactBlueprint.render(@contact), status: :ok
    else
      render_validation_errors(@contact)
    end
  end

  def destroy
    authorize @contact

    @contact.destroy!

    head :no_content
  end

  private

  def set_client
    @client = policy_scope(Client).find(params[:client_id])
  end

  def set_contact
    @contact = policy_scope(Contact).find(params[:id])
  end

  def contact_params
    params.require(:contact).permit(
      :nom,
      :prenom,
      :fonction,
      :email,
      :telephone,
      :principal
    )
  end
end
