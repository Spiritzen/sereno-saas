# frozen_string_literal: true

# Miroir de Api::V1::AvoirsController, mais NICHÉ sous factures (décision
# Sébastien, cf. rapport de reconnaissance du 31/07/2026) : un paiement n'a de
# sens qu'attaché à une facture précise, contrairement à l'avoir qui a sa
# propre page de détail. Actions retenues pour la v1 : index, create,
# confirmer, annuler — pas de show/update/destroy (un paiement confirmé ou
# annulé est immuable et non destructible, cf. Paiement, étage A ; un
# paiement brouillon se corrige en le recréant, pas en le modifiant ici).
#
# Toute l'orchestration transactionnelle (paiement + EvenementPaiement) est
# déjà posée dans PaiementService (étage A) — ce contrôleur ne fait
# qu'appeler, jamais réimplémenter.
class Api::V1::PaiementsController < Api::V1::BaseController
  before_action :set_facture, only: [ :index, :create ]
  before_action :set_paiement, only: [ :confirmer, :annuler ]

  def index
    paiements = policy_scope(Paiement)
                .where(facture_id: @facture.id)
                .order(created_at: :desc)

    render json: PaiementBlueprint.render(paiements), status: :ok
  end

  def create
    paiement_pour_autorisation = Paiement.new(
      organisation: Current.organisation,
      facture: @facture
    )

    authorize paiement_pour_autorisation, :create?

    paiement = paiement_service.enregistrer!(
      facture: @facture,
      attributs: paiement_params.to_h.symbolize_keys
    )

    render json: PaiementBlueprint.render(paiement), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_errors(e.record)
  end

  def confirmer
    authorize @paiement, :confirmer?

    paiement = paiement_service.confirmer!(paiement: @paiement)

    render json: PaiementBlueprint.render(paiement), status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_errors(e.record)
  end

  def annuler
    authorize @paiement, :annuler?

    paiement = paiement_service.annuler!(paiement: @paiement)

    render json: PaiementBlueprint.render(paiement), status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_errors(e.record)
  end

  private

  def paiement_service
    PaiementService.new(organisation: Current.organisation, utilisateur: Current.utilisateur)
  end

  def set_facture
    @facture = policy_scope(Facture).find(params[:facture_id])
  end

  def set_paiement
    @paiement = policy_scope(Paiement).where(facture_id: params[:facture_id]).find(params[:id])
  end

  def paiement_params
    params.require(:paiement).permit(:montant, :methode_code, :date_encaissement, :reference)
  end
end
