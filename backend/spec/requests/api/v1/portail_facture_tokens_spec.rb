# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::PortailFactureTokens", type: :request do
  def authenticate_as(utilisateur, organisation)
    allow_any_instance_of(Api::V1::BaseController)
      .to receive(:authenticate_request!) do
        Current.organisation = organisation
        Current.utilisateur = utilisateur
        Current.session = nil
      end
  end

  after { Current.reset }

  it "refuse l'accès sans authentification (génération)" do
    facture = create(:facture, :emise, date_echeance: 1.day.ago)

    post "/api/v1/factures/#{facture.id}/lien_portail"

    expect(response).to have_http_status(:unauthorized)
  end

  describe "T-ISOLATION (décisif)" do
    let(:organisation_a) { create(:organisation) }
    let(:organisation_b) { create(:organisation) }
    let(:utilisateur_b) { create(:utilisateur, organisation: organisation_b, role: "owner") }
    let(:facture_a) { create(:facture, :emise, organisation: organisation_a, date_echeance: 1.day.ago) }

    it "refuse à l'organisation B de générer un lien pour une facture de A (404)" do
      authenticate_as(utilisateur_b, organisation_b)

      post "/api/v1/factures/#{facture_a.id}/lien_portail"

      expect(response).to have_http_status(:not_found)
      expect(PortailFactureToken.count).to eq(0)
    end
  end

  describe "T-ROLE (owner + membre ; comptable et super_admin exclus, miroir RelancePolicy)" do
    let(:organisation) { create(:organisation) }
    let(:facture) { create(:facture, :emise, organisation: organisation, date_echeance: 1.day.ago) }

    it "refuse à un comptable de générer un lien (403)" do
      utilisateur = create(:utilisateur, organisation: organisation, role: "comptable")
      authenticate_as(utilisateur, organisation)

      post "/api/v1/factures/#{facture.id}/lien_portail"

      expect(response).to have_http_status(:forbidden)
      expect(PortailFactureToken.count).to eq(0)
    end

    it "refuse à un super_admin de générer un lien (403)" do
      utilisateur = create(:utilisateur, organisation: organisation, role: "super_admin")
      authenticate_as(utilisateur, organisation)

      post "/api/v1/factures/#{facture.id}/lien_portail"

      expect(response).to have_http_status(:forbidden)
    end

    it "autorise un membre à générer un lien" do
      utilisateur = create(:utilisateur, organisation: organisation, role: "membre")
      authenticate_as(utilisateur, organisation)

      post "/api/v1/factures/#{facture.id}/lien_portail"

      expect(response).to have_http_status(:created)
    end

    it "autorise un owner à générer un lien" do
      utilisateur = create(:utilisateur, organisation: organisation, role: "owner")
      authenticate_as(utilisateur, organisation)

      post "/api/v1/factures/#{facture.id}/lien_portail"

      expect(response).to have_http_status(:created)
    end

    it "refuse à un comptable de révoquer (403)" do
      utilisateur = create(:utilisateur, organisation: organisation, role: "comptable")
      authenticate_as(utilisateur, organisation)

      delete "/api/v1/factures/#{facture.id}/lien_portail"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "T-CREATE" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }
    let(:facture) { create(:facture, :emise, organisation: organisation, date_echeance: 1.day.ago) }

    before { authenticate_as(utilisateur, organisation) }

    it "génère un token et renvoie une URL avec le token BRUT — l'URL ne porte QUE le token" do
      post "/api/v1/factures/#{facture.id}/lien_portail"

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["url"]).to match(%r{/portail/[0-9a-f]{128}\z})
      expect(body["url"]).not_to include(facture.id)
      expect(PortailFactureToken.count).to eq(1)
    end

    it "révoque implicitement tout lien actif précédent en générant un nouveau (choix le plus simple)" do
      premier = PortailFactureToken.generer!(facture: facture)

      post "/api/v1/factures/#{facture.id}/lien_portail"

      expect(premier.token.reload.revoque_at).to be_present
      expect(PortailFactureToken.where(facture_id: facture.id, revoque_at: nil).count).to eq(1)
    end
  end

  describe "T-DESTROY" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }
    let(:facture) { create(:facture, :emise, organisation: organisation, date_echeance: 1.day.ago) }

    before { authenticate_as(utilisateur, organisation) }

    it "révoque le(s) token(s) actif(s) — immédiat, le lien brut ne résout plus rien" do
      resultat = PortailFactureToken.generer!(facture: facture)

      delete "/api/v1/factures/#{facture.id}/lien_portail"

      expect(response).to have_http_status(:no_content)
      expect(PortailFactureToken.resoudre(resultat.brut)).to be_nil
    end

    it "reste sans effet (204) s'il n'existe aucun token actif" do
      delete "/api/v1/factures/#{facture.id}/lien_portail"

      expect(response).to have_http_status(:no_content)
    end
  end
end
