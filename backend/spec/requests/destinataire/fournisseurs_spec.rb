# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Destinataire::Fournisseurs", type: :request do
  def authenticate_as(compte)
    session = DestinataireSession.generer!(compte_destinataire: compte).session
    allow_any_instance_of(Destinataire::BaseController)
      .to receive(:authenticate_destinataire!) do
        Current.compte_destinataire = compte
        Current.destinataire_session = session
      end
  end

  after { Current.reset }

  def lier!(compte, client, facture)
    DestinataireClientLink.create!(
      compte_destinataire: compte, client: client, cree_via: "lien_portail", facture_id_preuve: facture.id
    )
  end

  let(:organisation) { create(:organisation, raison_sociale: "Fournisseur Un") }
  let(:client) { create(:client, organisation: organisation) }
  let(:facture) { create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago) }
  let(:compte) { create(:compte_destinataire) }

  describe "GET /destinataire/fournisseurs" do
    it "renvoie chaque fournisseur revendiqué avec son nombre de factures" do
      autre_facture = create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago)
      lier!(compte, client, facture)
      authenticate_as(compte)

      get "/destinataire/fournisseurs"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.size).to eq(1)
      expect(body.first["fournisseur"]["raison_sociale"]).to eq("Fournisseur Un")
      expect(body.first["nombre_factures"]).to eq(2)
      expect(autre_facture).to be_persisted
    end

    it "groupe correctement sur plusieurs fournisseurs, RIEN d'un fournisseur non revendiqué" do
      organisation_b = create(:organisation, raison_sociale: "Fournisseur Deux")
      client_b = create(:client, organisation: organisation_b)
      facture_b = create(:facture, :emise, organisation: organisation_b, client: client_b, date_echeance: 1.day.ago)

      organisation_c = create(:organisation, raison_sociale: "Fournisseur Trois (non lié)")
      client_c = create(:client, organisation: organisation_c)
      create(:facture, :emise, organisation: organisation_c, client: client_c, date_echeance: 1.day.ago)

      lier!(compte, client, facture)
      lier!(compte, client_b, facture_b)
      authenticate_as(compte)

      get "/destinataire/fournisseurs"

      body = JSON.parse(response.body)
      noms = body.map { |entree| entree["fournisseur"]["raison_sociale"] }
      expect(noms).to contain_exactly("Fournisseur Un", "Fournisseur Deux")
    end

    it "exclut les brouillons du décompte" do
      create(:facture, organisation: organisation, client: client, date_echeance: 1.day.ago) # brouillon
      lier!(compte, client, facture)
      authenticate_as(compte)

      get "/destinataire/fournisseurs"

      body = JSON.parse(response.body)
      expect(body.first["nombre_factures"]).to eq(1)
    end

    it "aucun fournisseur revendiqué -> liste vide" do
      authenticate_as(create(:compte_destinataire))

      get "/destinataire/fournisseurs"

      expect(JSON.parse(response.body)).to eq([])
    end

    it "sans authentification -> 401" do
      get "/destinataire/fournisseurs"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
