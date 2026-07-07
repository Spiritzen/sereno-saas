# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::LignesFacture", type: :request do
  def authenticate_as(utilisateur, organisation)
    allow_any_instance_of(Api::V1::BaseController)
      .to receive(:authenticate_request!) do
        Current.organisation = organisation
        Current.utilisateur = utilisateur
        Current.session = nil
      end
  end

  def ligne_params(attributes = {})
    {
      ligne_facture: {
        designation: "Prestation sécurisée",
        quantite: 2,
        prix_unitaire_ht: 150,
        taux_tva: 20,
        position: 1
      }.merge(attributes)
    }
  end

  after do
    Current.reset
  end

  describe "isolation tenant" do
    let(:organisation_a) { create(:organisation) }
    let(:organisation_b) { create(:organisation) }
    let(:utilisateur_a) { create(:utilisateur, organisation: organisation_a, role: "owner") }

    before do
      authenticate_as(utilisateur_a, organisation_a)
    end

    it "empêche de lister les lignes d'une facture d'une autre organisation" do
      facture_b = create(:facture, :avec_ligne, organisation: organisation_b)

      get "/api/v1/factures/#{facture_b.id}/lignes"

      expect(response).to have_http_status(:not_found)
    end

    it "empêche de modifier une ligne appartenant à une autre organisation" do
      facture_b = create(:facture, :avec_ligne, organisation: organisation_b)
      ligne_b = facture_b.lignes_facture.first

      patch "/api/v1/lignes-facture/#{ligne_b.id}", params: ligne_params(
        designation: "Tentative cross-tenant"
      )

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "lignes sur facture brouillon" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }

    before do
      authenticate_as(utilisateur, organisation)
    end

    it "autorise la création d'une ligne sur une facture brouillon" do
      facture = create(:facture, organisation: organisation)

      expect do
        post "/api/v1/factures/#{facture.id}/lignes", params: ligne_params
      end.to change(LigneFacture, :count).by(1)

      expect(response).to have_http_status(:created)

      facture.reload
      expect(facture.lignes_facture.count).to eq(1)
      expect(facture.total_ttc).to be > 0
    end

    it "autorise la modification d'une ligne sur une facture brouillon" do
      facture = create(:facture, :avec_ligne, organisation: organisation)
      ligne = facture.lignes_facture.first

      patch "/api/v1/lignes-facture/#{ligne.id}", params: ligne_params(
        designation: "Prestation modifiée",
        quantite: 3
      )

      expect(response).to have_http_status(:ok)

      ligne.reload
      expect(ligne.designation).to eq("Prestation modifiée")
      expect(ligne.quantite).to eq(3)
    end

    it "autorise la suppression d'une ligne sur une facture brouillon" do
      facture = create(:facture, :avec_ligne, organisation: organisation)
      ligne = facture.lignes_facture.first

      expect do
        delete "/api/v1/lignes-facture/#{ligne.id}"
      end.to change(LigneFacture, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "immutabilité des lignes après émission" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }

    before do
      authenticate_as(utilisateur, organisation)
    end

    it "refuse l'ajout d'une ligne sur une facture émise" do
      facture = create(:facture, :emise, organisation: organisation)

      expect do
        post "/api/v1/factures/#{facture.id}/lignes", params: ligne_params
      end.not_to change(LigneFacture, :count)

      expect(response).to have_http_status(:forbidden)
    end

    it "refuse la modification d'une ligne sur une facture émise" do
      facture = create(:facture, :emise, organisation: organisation)
      ligne = facture.lignes_facture.first
      ancienne_designation = ligne.designation
      ancienne_quantite = ligne.quantite

      patch "/api/v1/lignes-facture/#{ligne.id}", params: ligne_params(
        designation: "Modification interdite",
        quantite: 99
      )

      expect(response).to have_http_status(:forbidden)

      ligne.reload
      expect(ligne.designation).to eq(ancienne_designation)
      expect(ligne.quantite).to eq(ancienne_quantite)
    end

    it "refuse la suppression d'une ligne sur une facture émise" do
      facture = create(:facture, :emise, organisation: organisation)
      ligne = facture.lignes_facture.first

      expect do
        delete "/api/v1/lignes-facture/#{ligne.id}"
      end.not_to change(LigneFacture, :count)

      expect(response).to have_http_status(:forbidden)
      expect(LigneFacture.exists?(ligne.id)).to be(true)
    end
  end
end
