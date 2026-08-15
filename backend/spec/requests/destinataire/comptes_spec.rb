# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Destinataire::Comptes", type: :request do
  def authenticate_as(compte)
    session = DestinataireSession.generer!(compte_destinataire: compte).session
    allow_any_instance_of(Destinataire::BaseController)
      .to receive(:authenticate_destinataire!) do
        Current.compte_destinataire = compte
        Current.destinataire_session = session
      end
  end

  after { Current.reset }

  describe "DELETE /destinataire/compte (RGPD)" do
    it "avec le bon mot de passe : détruit le compte, ses sessions ET ses liens (cascade)" do
      compte = create(:compte_destinataire, mot_de_passe: "motdepasse123")
      create(:destinataire_client_link, compte_destinataire: compte)
      DestinataireSession.generer!(compte_destinataire: compte)
      authenticate_as(compte)

      compte_id = compte.id

      delete "/destinataire/compte", params: { mot_de_passe: "motdepasse123" }

      expect(response).to have_http_status(:ok)
      expect(CompteDestinataire.exists?(compte_id)).to be(false)
      expect(DestinataireClientLink.where(compte_destinataire_id: compte_id)).to be_empty
      expect(DestinataireSession.where(compte_destinataire_id: compte_id)).to be_empty
    end

    it "mauvais mot de passe -> 401, le compte n'est PAS supprimé (une session active ne suffit pas)" do
      compte = create(:compte_destinataire, mot_de_passe: "motdepasse123")
      authenticate_as(compte)

      delete "/destinataire/compte", params: { mot_de_passe: "mauvais-mot-de-passe" }

      expect(response).to have_http_status(:unauthorized)
      expect(CompteDestinataire.exists?(compte.id)).to be(true)
    end

    it "sans authentification -> 401" do
      delete "/destinataire/compte", params: { mot_de_passe: "peuimporte" }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
