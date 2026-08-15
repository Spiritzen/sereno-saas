# frozen_string_literal: true

# Endpoints OWNER (authentifiés, sous api/v1) pour générer/révoquer le lien
# de partage public d'UNE facture. Miroir de Api::V1::RelancesController :
# toute la logique (génération, hash, expiration, URL) vit dans
# PortailFactureToken — ce contrôleur ne fait qu'appeler, jamais réimplémenter.
#
# Un seul lien ACTIF à la fois par facture, POUR CE CHEMIN OWNER (choix le
# plus simple, cf. §3 execution_portail_destinataire_mvp.txt) : générer
# révoque implicitement tout lien précédent — de toute façon son token BRUT
# n'est plus récupérable (jamais stocké), le renvoyer tel quel est
# structurellement impossible. ⚠️ Comportement INCHANGÉ par le fast-follow
# "lien dans la relance" (15/08/2026) : RelanceService, lui, ne révoque rien
# (plusieurs liens actifs possibles) — deux politiques différentes, un seul
# constructeur d'URL partagé (PortailFactureToken.url_publique).
#
# La base d'URL (PortailFactureToken.frontend_base_url) est désormais
# VALIDÉE : en production, une FRONTEND_URL absente ou invalide lève
# Portail::UrlNonConfiguree plutôt que d'envoyer un lien cassé (plus de
# placeholder "https://app.sereno.fr").
class Api::V1::PortailFactureTokensController < Api::V1::BaseController
  before_action :set_facture

  def create
    autorisation = PortailFactureToken.new(organisation: Current.organisation, facture: @facture)
    authorize autorisation, :create?

    revoquer_tokens_actifs!

    resultat = PortailFactureToken.generer!(facture: @facture)

    render json: { url: PortailFactureToken.url_publique(resultat.brut) }, status: :created
  end

  def destroy
    autorisation = PortailFactureToken.new(organisation: Current.organisation, facture: @facture)
    authorize autorisation, :destroy?

    revoquer_tokens_actifs!

    head :no_content
  end

  private

  def set_facture
    # Route membre (`on: :member`, imbriquée sous resources :factures) : le
    # paramètre s'appelle :id, pas :facture_id (cf. config/routes.rb).
    @facture = policy_scope(Facture).find(params[:id])
  end

  def revoquer_tokens_actifs!
    @facture.portail_facture_tokens.where(revoque_at: nil).find_each(&:revoquer!)
  end
end
