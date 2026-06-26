# frozen_string_literal: true

class Api::V1::FacturesController < Api::V1::BaseController
  before_action :set_facture, only: [:show, :update, :destroy, :emettre, :conformite, :factur_x_xml, :pdf]

  def index
    factures = policy_scope(Facture)
               .includes(:client)
               .order(created_at: :desc)

    factures = factures.where(statut: params[:statut]) if params[:statut].present?
    factures = factures.where(client_id: params[:client_id]) if params[:client_id].present?

    render json: FactureBlueprint.render(factures), status: :ok
  end

  def show
    authorize @facture

    render json: FactureBlueprint.render(@facture, view: :with_details), status: :ok
  end

  def conformite
  authorize @facture, :conformite?

  resultat = FactureConformiteService.new(facture: @facture).call

  render json: resultat.to_h, status: :ok
  end

  def pdf
  authorize @facture, :pdf?

  chemin_fichier = FacturePdfService.new(facture: @facture).call

  disposition = params[:download].present? ? "attachment" : "inline"

  send_file chemin_fichier,
            type: "application/pdf",
            disposition: disposition,
            filename: "facture-#{@facture.numero}.pdf"
  rescue FacturePdfService::PdfGenerationImpossibleError => e
  render json: {
    error: "Génération PDF impossible",
    details: [e.message]
  }, status: :unprocessable_entity
  end

  def create
    attributes = facture_params.to_h.symbolize_keys

    client_id = attributes.delete(:client_id)
    devis_id = attributes.delete(:devis_id)

    return render json: { error: "client_id est obligatoire" }, status: :unprocessable_entity if client_id.blank?

    client = policy_scope(Client).find(client_id)

    facture = Current.organisation.factures.new(default_facture_attributes.merge(attributes))
    facture.client = client

    if devis_id.present?
      facture.devis = Current.organisation.devis.find(devis_id)
    end

    authorize facture

    if facture.save
      render json: FactureBlueprint.render(facture, view: :with_details), status: :created
    else
      render_validation_errors(facture)
    end
  end

  def update
    authorize @facture

    attributes = facture_params.to_h.symbolize_keys

    client_id = attributes.delete(:client_id)
    devis_id = attributes.delete(:devis_id)

    @facture.client = policy_scope(Client).find(client_id) if client_id.present?

    if devis_id.present?
      @facture.devis = Current.organisation.devis.find(devis_id)
    elsif attributes.key?(:devis_id)
      @facture.devis = nil
    end

    @facture.assign_attributes(attributes)

    if @facture.save
      render json: FactureBlueprint.render(@facture, view: :with_details), status: :ok
    else
      render_validation_errors(@facture)
    end
  end

  def destroy
    authorize @facture

    @facture.destroy!

    head :no_content
  rescue ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey
    render json: {
      error: "Suppression impossible",
      details: ["Cette facture est liée à des documents métier."]
    }, status: :unprocessable_entity
  end

def factur_x_xml
  authorize @facture, :factur_x_xml?

  chemin_fichier = FacturXStorageService.new(facture: @facture).call

  disposition = params[:download].present? ? "attachment" : "inline"

  send_file chemin_fichier,
            type: "application/xml; charset=utf-8",
            disposition: disposition,
            filename: "factur-x-#{@facture.numero}.xml"
rescue FacturXXmlService::GenerationImpossibleError, FacturXStorageService::StorageImpossibleError => e
  render json: {
    error: "Génération XML impossible",
    details: [e.message]
  }, status: :unprocessable_entity
end

  def emettre
  authorize @facture, :emettre?

  facture_emise = FactureEmissionService.new(
    facture: @facture,
    utilisateur: Current.utilisateur
  ).call

  render json: FactureBlueprint.render(facture_emise.reload, view: :with_details), status: :ok
rescue FactureEmissionService::EmissionImpossibleError => e
  render json: {
    error: "Émission impossible",
    details: e.details
  }, status: :unprocessable_entity
rescue ActiveRecord::RecordInvalid => e
  render_validation_errors(e.record)
end

  private

  def set_facture
    @facture = policy_scope(Facture).find(params[:id])
  end

  def default_facture_attributes
    {
      type_document: "facture",
      statut: "brouillon",
      total_ht: 0,
      total_tva: 0,
      total_ttc: 0,
      montant_paye: 0,
      devise: "EUR",
      format: "factur_x"
    }
  end

  def facture_params
    params.require(:facture).permit(
      :client_id,
      :devis_id,
      :type_document,
      :date_echeance,
      :devise,
      :format,
      :mentions,
      :conditions_paiement
    )
  end
end