# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Destinataire::Moi", type: :request do
  def authenticate_as(compte)
    session = DestinataireSession.generer!(compte_destinataire: compte).session
    allow_any_instance_of(Destinataire::BaseController)
      .to receive(:authenticate_destinataire!) do
        Current.compte_destinataire = compte
        Current.destinataire_session = session
      end
  end

  after { Current.reset }

  describe "GET /destinataire/moi" do
    it "renvoie l'identité minimale du compte — AUCUNE donnée de facture (étape B)" do
      compte = create(:compte_destinataire, email: "moi@test.fr")
      create(:destinataire_client_link, compte_destinataire: compte)
      authenticate_as(compte)

      get "/destinataire/moi"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["email"]).to eq("moi@test.fr")
      expect(body["fournisseurs_lies"]).to eq(1)
      expect(body).not_to have_key("factures")
      expect(body).not_to have_key("client_ids")
    end

    it "sans authentification -> 401" do
      get "/destinataire/moi"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
