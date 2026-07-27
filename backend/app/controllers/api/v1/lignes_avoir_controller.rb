# frozen_string_literal: true

# Miroir de Api::V1::LignesFactureController, adapté aux colonnes réelles de
# LigneAvoir (pas de produit_id/montant_tva/total_ttc, cf. V1.2a). Toutes les
# actions nichées sous /avoirs/:avoir_id/lignes (pas de route à plat comme
# lignes-facture : non nécessaire ici, le frontend connaît déjà l'avoir_id).
#
# Recalcul des totaux : ENTIÈREMENT CÔTÉ BACKEND, déjà câblé depuis V1.2a
# (LigneAvoir#after_save/#after_destroy -> Avoir#recalculer_totaux!) — ce
# contrôleur ne recalcule rien lui-même, il se contente de sauvegarder/
# détruire la ligne et de relire l'avoir à jour.
#
# Immutabilité : PAS de vérification dans la policy (cf. LigneAvoirPolicy).
# Le modèle bloque déjà save/destroy sur un avoir non-brouillon
# (LigneAvoir#avoir_modifiable, #empecher_suppression_si_avoir_emis) ; ces
# échecs remontent naturellement en 422 (render_validation_errors / rescue
# RecordNotDestroyed ci-dessous), jamais en 403.
class Api::V1::LignesAvoirController < Api::V1::BaseController
  before_action :set_avoir
  before_action :set_ligne_avoir, only: [ :update, :destroy ]

  def create
    ligne = @avoir.lignes_avoir.new
    ligne.organisation = Current.organisation

    assign_ligne_attributes(ligne)

    authorize ligne

    if ligne.save
      render json: AvoirBlueprint.render(@avoir.reload, view: :with_details), status: :created
    else
      render_validation_errors(ligne)
    end
  end

  def update
    authorize @ligne_avoir

    assign_ligne_attributes(@ligne_avoir)

    if @ligne_avoir.save
      render json: AvoirBlueprint.render(@ligne_avoir.avoir.reload, view: :with_details), status: :ok
    else
      render_validation_errors(@ligne_avoir)
    end
  end

  def destroy
    authorize @ligne_avoir

    avoir = @ligne_avoir.avoir
    @ligne_avoir.destroy!

    render json: AvoirBlueprint.render(avoir.reload, view: :with_details), status: :ok
  rescue ActiveRecord::RecordNotDestroyed => e
    render json: {
      error: "Suppression impossible",
      details: e.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  private

  def set_avoir
    @avoir = policy_scope(Avoir).find(params[:avoir_id])
  end

  def set_ligne_avoir
    @ligne_avoir = policy_scope(LigneAvoir).where(avoir_id: @avoir.id).find(params[:id])
  end

  def assign_ligne_attributes(ligne)
    ligne.assign_attributes(ligne_avoir_params)
  end

  def ligne_avoir_params
    params.require(:ligne_avoir).permit(
      :designation,
      :quantite,
      :prix_unitaire_ht,
      :taux_tva,
      :position
    )
  end
end
