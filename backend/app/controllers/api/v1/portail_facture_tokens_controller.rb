# frozen_string_literal: true

# Endpoints OWNER (authentifiés, sous api/v1) pour générer/révoquer le lien
# de partage public d'UNE facture. Miroir de Api::V1::RelancesController :
# toute la logique (génération, hash, expiration) vit dans PortailFactureToken
# — ce contrôleur ne fait qu'appeler, jamais réimplémenter.
#
# Un seul lien ACTIF à la fois par facture (choix le plus simple, cf. §3
# execution_portail_destinataire_mvp.txt) : générer révoque implicitement
# tout lien précédent — de toute façon son token BRUT n'est plus récupérable
# (jamais stocké), le renvoyer tel quel est structurellement impossible.
class Api::V1::PortailFactureTokensController < Api::V1::BaseController
  before_action :set_facture

  def create
    autorisation = PortailFactureToken.new(organisation: Current.organisation, facture: @facture)
    authorize autorisation, :create?

    revoquer_tokens_actifs!

    resultat = PortailFactureToken.generer!(facture: @facture)

    render json: { url: url_portail(resultat.brut) }, status: :created
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

  def url_portail(token_brut)
    "#{frontend_base_url}/portail/#{token_brut}"
  end

  # Même convention que CORS_ALLOWED_ORIGINS (config/initializers/cors.rb) :
  # ENV en prod, http://localhost:5173 (Vite) par défaut ailleurs.
  def frontend_base_url
    ENV.fetch("FRONTEND_URL", Rails.env.production? ? "https://app.sereno.fr" : "http://localhost:5173")
  end
end
