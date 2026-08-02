# frozen_string_literal: true

# Miroir de Api::V1::LignesAvoirController. Toutes les actions nichées sous
# /devis/:devis_id/lignes.
#
# Recalcul des totaux : ENTIÈREMENT CÔTÉ BACKEND, câblé depuis l'étage A
# (LigneDevis#after_save/#after_destroy -> Devis#recalculer_totaux!, via
# FactureTotalsService) — ce contrôleur ne recalcule rien lui-même.
#
# Immutabilité : PAS de vérification dans la policy (cf. LigneDevisPolicy).
# Le modèle bloque déjà save/destroy sur un devis non-brouillon
# (LigneDevis#devis_modifiable, #empecher_suppression_si_devis_non_brouillon) ;
# ces échecs remontent naturellement en 422, jamais en 403.
class Api::V1::LignesDevisController < Api::V1::BaseController
  before_action :set_devis
  before_action :set_ligne_devis, only: [ :update, :destroy ]

  def create
    ligne = @devis.lignes_devis.new
    ligne.organisation = Current.organisation

    assign_ligne_attributes(ligne)

    authorize ligne

    if ligne.save
      render json: DevisBlueprint.render(@devis.reload, view: :with_details), status: :created
    else
      render_validation_errors(ligne)
    end
  end

  def update
    authorize @ligne_devis

    assign_ligne_attributes(@ligne_devis)

    if @ligne_devis.save
      render json: DevisBlueprint.render(@ligne_devis.devis.reload, view: :with_details), status: :ok
    else
      render_validation_errors(@ligne_devis)
    end
  end

  def destroy
    authorize @ligne_devis

    devis = @ligne_devis.devis
    @ligne_devis.destroy!

    render json: DevisBlueprint.render(devis.reload, view: :with_details), status: :ok
  rescue ActiveRecord::RecordNotDestroyed => e
    render json: {
      error: "Suppression impossible",
      details: e.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  private

  def set_devis
    @devis = policy_scope(Devis).find(params[:devis_id])
  end

  def set_ligne_devis
    @ligne_devis = policy_scope(LigneDevis).where(devis_id: @devis.id).find(params[:id])
  end

  def assign_ligne_attributes(ligne)
    ligne.assign_attributes(ligne_devis_params)
  end

  def ligne_devis_params
    params.require(:ligne_devis).permit(
      :designation,
      :quantite,
      :prix_unitaire_ht,
      :taux_tva,
      :position
    )
  end
end
