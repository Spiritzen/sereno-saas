# frozen_string_literal: true

# Miroir de Api::V1::FacturesController. Pas de gestion des lignes ici :
# aucun endpoint lignes_avoir n'est demandé dans ce sprint (V1.2b) — un
# avoir brouillon est créé sans ligne, à compléter par un sprint ultérieur
# (cf. rapport). L'émission (AvoirEmissionService, via AvoirConformiteService)
# refuse déjà, avec un message explicite, un avoir sans ligne.
class Api::V1::AvoirsController < Api::V1::BaseController
  before_action :set_avoir, only: [ :show, :emettre, :pdf, :avoir_x_xml ]

  def index
    avoirs = policy_scope(Avoir)
             .includes(:client, :facture)
             .order(created_at: :desc)

    avoirs = avoirs.where(facture_id: params[:facture_id]) if params[:facture_id].present?

    render json: AvoirBlueprint.render(avoirs), status: :ok
  end

  def show
    authorize @avoir

    render json: AvoirBlueprint.render(@avoir, view: :with_details), status: :ok
  end

  def create
    attributes = avoir_params.to_h.symbolize_keys
    facture_id = attributes.delete(:facture_id)

    return render json: { error: "facture_id est obligatoire" }, status: :unprocessable_entity if facture_id.blank?

    facture = policy_scope(Facture).find(facture_id)

    avoir = Current.organisation.avoirs.new(
      default_avoir_attributes.merge(attributes)
    )
    avoir.facture = facture
    avoir.client = facture.client

    authorize avoir

    return render_validation_errors(avoir) unless avoir.valid?

    ActiveRecord::Base.transaction do
      avoir.save!
      creer_evenement_creation!(avoir)
    end

    render json: AvoirBlueprint.render(avoir, view: :with_details), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_errors(e.record)
  end

  def emettre
    authorize @avoir, :emettre?

    avoir_emis = AvoirEmissionService.new(
      avoir: @avoir,
      utilisateur: Current.utilisateur
    ).call

    render json: AvoirBlueprint.render(avoir_emis.reload, view: :with_details), status: :ok
  rescue AvoirEmissionService::EmissionImpossibleError => e
    render json: {
      error: "Émission impossible",
      details: e.details
    }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render_validation_errors(e.record)
  end

  def pdf
    authorize @avoir, :pdf?

    chemin_fichier = chemin_archive(@avoir.pdf_url)

    unless chemin_fichier && File.exist?(chemin_fichier)
      return render json: {
        error: "PDF indisponible",
        details: [ "Le PDF archivé n'est pas disponible pour cet avoir" ]
      }, status: :not_found
    end

    disposition = params[:download].present? ? "attachment" : "inline"

    send_file chemin_fichier,
              type: "application/pdf",
              disposition: disposition,
              filename: "avoir-#{@avoir.numero}.pdf"
  end

  def avoir_x_xml
    authorize @avoir, :avoir_x_xml?

    chemin_fichier = chemin_archive(@avoir.xml_url)

    unless chemin_fichier && File.exist?(chemin_fichier)
      return render json: {
        error: "XML indisponible",
        details: [ "Le XML Factur-X archivé n'est pas disponible pour cet avoir" ]
      }, status: :not_found
    end

    disposition = params[:download].present? ? "attachment" : "inline"

    send_file chemin_fichier,
              type: "application/xml; charset=utf-8",
              disposition: disposition,
              filename: "avoir-#{@avoir.numero}.xml"
  end

  private

  def set_avoir
    @avoir = policy_scope(Avoir).find(params[:id])
  end

  def creer_evenement_creation!(avoir)
    EvenementAvoir.create!(
      organisation_id: avoir.organisation_id,
      avoir_id: avoir.id,
      utilisateur_id: Current.utilisateur.id,
      statut: "brouillon",
      source: "interne",
      payload: {
        action: "avoir_cree"
      }
    )
  end

  def default_avoir_attributes
    {
      statut: "brouillon",
      total_ht: 0,
      total_tva: 0,
      total_ttc: 0
    }
  end

  def avoir_params
    params.require(:avoir).permit(:facture_id, :motif)
  end

  def chemin_archive(chemin_relatif)
    return nil if chemin_relatif.blank?

    Rails.root.join(chemin_relatif)
  end
end
