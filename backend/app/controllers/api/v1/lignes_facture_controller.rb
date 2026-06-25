# frozen_string_literal: true

class Api::V1::LignesFactureController < Api::V1::BaseController
  before_action :set_facture, only: [:index, :create]
  before_action :set_ligne_facture, only: [:show, :update, :destroy]

  def index
    lignes = policy_scope(LigneFacture)
             .where(facture: @facture)
             .order(:position)

    render json: LigneFactureBlueprint.render(lignes), status: :ok
  end

  def show
    authorize @ligne_facture

    render json: LigneFactureBlueprint.render(@ligne_facture), status: :ok
  end

  def create
    ligne = @facture.lignes_facture.new
    ligne.organisation = Current.organisation

    assign_ligne_attributes(ligne)

    authorize ligne

    if ligne.save
      render json: FactureBlueprint.render(@facture.reload, view: :with_details), status: :created
    else
      render_validation_errors(ligne)
    end
  end

  def update
    authorize @ligne_facture

    assign_ligne_attributes(@ligne_facture)

    if @ligne_facture.save
      render json: FactureBlueprint.render(@ligne_facture.facture.reload, view: :with_details), status: :ok
    else
      render_validation_errors(@ligne_facture)
    end
  end

  def destroy
    authorize @ligne_facture

    facture = @ligne_facture.facture
    @ligne_facture.destroy!

    render json: FactureBlueprint.render(facture.reload, view: :with_details), status: :ok
  end

  private

  def set_facture
    @facture = policy_scope(Facture).find(params[:facture_id])
  end

  def set_ligne_facture
    @ligne_facture = policy_scope(LigneFacture).find(params[:id])
  end

  def assign_ligne_attributes(ligne)
    attributes = ligne_facture_params.to_h.symbolize_keys

    produit_id_present = attributes.key?(:produit_id)
    produit_id = attributes.delete(:produit_id)

    ligne.assign_attributes(attributes)

    return unless produit_id_present

    ligne.produit = if produit_id.present?
                      Current.organisation.produits.find(produit_id)
                    else
                      nil
                    end
  end

  def ligne_facture_params
    params.require(:ligne_facture).permit(
      :produit_id,
      :designation,
      :quantite,
      :prix_unitaire_ht,
      :taux_tva,
      :position
    )
  end
end