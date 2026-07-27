# frozen_string_literal: true

require "rails_helper"

# V1.2b-bis — gabarit littéral de lignes_facture_spec.rb, adapté à l'avoir.
# DIVERGENCE ASSUMÉE (cf. LigneAvoirPolicy) : l'immutabilité après émission
# renvoie ici 422 (erreur de validation modèle), PAS 403 comme pour la
# facture — la policy avoir ne porte AUCUNE règle d'éligibilité (rôle+tenant
# uniquement), conformément à la leçon générale du projet et à la consigne
# explicite du prompt V1.2b-bis.
RSpec.describe "Api::V1::LignesAvoir", type: :request do
  def authenticate_as(utilisateur, organisation)
    allow_any_instance_of(Api::V1::BaseController)
      .to receive(:authenticate_request!) do
        Current.organisation = organisation
        Current.utilisateur = utilisateur
        Current.session = nil
      end
  end

  after { Current.reset }

  def ligne_params(attributes = {})
    {
      ligne_avoir: {
        designation: "Correction facturée",
        quantite: 2,
        prix_unitaire_ht: 150,
        taux_tva: 20,
        position: 1
      }.merge(attributes)
    }
  end

  describe "T-LIGNE-ISOLATION (décisif)" do
    let(:organisation_a) { create(:organisation) }
    let(:organisation_b) { create(:organisation) }
    let(:utilisateur_a) { create(:utilisateur, organisation: organisation_a, role: "owner") }

    before { authenticate_as(utilisateur_a, organisation_a) }

    it "empêche d'ajouter une ligne à l'avoir d'une autre organisation (404)" do
      avoir_b = create(:avoir, organisation: organisation_b)

      expect do
        post "/api/v1/avoirs/#{avoir_b.id}/lignes", params: ligne_params
      end.not_to change(LigneAvoir, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "empêche de modifier une ligne appartenant à l'avoir d'une autre organisation (404)" do
      avoir_b = create(:avoir, organisation: organisation_b)
      ligne_b = create(:ligne_avoir, avoir: avoir_b, organisation: organisation_b)

      patch "/api/v1/avoirs/#{avoir_b.id}/lignes/#{ligne_b.id}", params: ligne_params(
        designation: "Tentative cross-tenant"
      )

      expect(response).to have_http_status(:not_found)
      expect(ligne_b.reload.designation).not_to eq("Tentative cross-tenant")
    end

    it "empêche de supprimer une ligne appartenant à l'avoir d'une autre organisation (404)" do
      avoir_b = create(:avoir, organisation: organisation_b)
      ligne_b = create(:ligne_avoir, avoir: avoir_b, organisation: organisation_b)

      expect do
        delete "/api/v1/avoirs/#{avoir_b.id}/lignes/#{ligne_b.id}"
      end.not_to change(LigneAvoir, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "lignes sur avoir brouillon (T-LIGNE-CREATE / UPDATE / DELETE, T-TOTAUX-BACKEND)" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }

    before { authenticate_as(utilisateur, organisation) }

    it "T-LIGNE-CREATE : ajoute une ligne, recalcule les totaux CÔTÉ BACKEND, retourne l'avoir à jour" do
      avoir = create(:avoir, organisation: organisation)

      expect do
        post "/api/v1/avoirs/#{avoir.id}/lignes", params: ligne_params
      end.to change(LigneAvoir, :count).by(1)

      expect(response).to have_http_status(:created)

      avoir.reload
      expect(avoir.lignes_avoir.count).to eq(1)
      expect(avoir.total_ht).to eq(BigDecimal("300.0")) # 2 * 150, jamais envoyé par le client
      expect(avoir.total_ttc).to be > avoir.total_ht

      body = JSON.parse(response.body)
      expect(body["total_ht"].to_f).to eq(300.0)
    end

    it "T-TOTAUX-BACKEND (décisif) : un total envoyé par le client dans le payload est ignoré" do
      avoir = create(:avoir, organisation: organisation)

      post "/api/v1/avoirs/#{avoir.id}/lignes", params: ligne_params(total_ht: 999_999)

      expect(response).to have_http_status(:created)
      avoir.reload
      expect(avoir.total_ht).to eq(BigDecimal("300.0")) # calculé par le modèle, pas 999999
    end

    it "T-LIGNE-UPDATE : modifie une ligne et recalcule les totaux" do
      avoir = create(:avoir, organisation: organisation)
      ligne = create(:ligne_avoir, avoir: avoir, organisation: organisation, quantite: 1, prix_unitaire_ht: 100)
      avoir.reload

      patch "/api/v1/avoirs/#{avoir.id}/lignes/#{ligne.id}", params: ligne_params(
        designation: "Correction modifiée", quantite: 3, prix_unitaire_ht: 100
      )

      expect(response).to have_http_status(:ok)

      ligne.reload
      expect(ligne.designation).to eq("Correction modifiée")
      expect(ligne.quantite).to eq(3)

      avoir.reload
      expect(avoir.total_ht).to eq(BigDecimal("300.0"))
    end

    it "T-LIGNE-DELETE : supprime une ligne et recalcule les totaux" do
      avoir = create(:avoir, organisation: organisation)
      ligne_1 = create(:ligne_avoir, avoir: avoir, organisation: organisation, quantite: 1, prix_unitaire_ht: 100)
      create(:ligne_avoir, avoir: avoir, organisation: organisation, quantite: 1, prix_unitaire_ht: 50)
      avoir.reload
      expect(avoir.total_ht).to eq(BigDecimal("150.0"))

      expect do
        delete "/api/v1/avoirs/#{avoir.id}/lignes/#{ligne_1.id}"
      end.to change(LigneAvoir, :count).by(-1)

      expect(response).to have_http_status(:ok)
      avoir.reload
      expect(avoir.total_ht).to eq(BigDecimal("50.0"))
    end
  end

  describe "T-LIGNE-IMMUABLE (décisif) : avoir déjà émis" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }

    before { authenticate_as(utilisateur, organisation) }

    it "refuse l'ajout d'une ligne sur un avoir émis (422, pas 403), aucune ligne créée" do
      avoir = create(:avoir, :emise, organisation: organisation)

      expect do
        post "/api/v1/avoirs/#{avoir.id}/lignes", params: ligne_params
      end.not_to change(LigneAvoir, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "refuse la modification d'une ligne sur un avoir émis (422), aucun changement" do
      avoir = create(:avoir, :emise, organisation: organisation)
      ligne = avoir.lignes_avoir.first
      ancienne_designation = ligne.designation

      patch "/api/v1/avoirs/#{avoir.id}/lignes/#{ligne.id}", params: ligne_params(
        designation: "Modification interdite"
      )

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ligne.reload.designation).to eq(ancienne_designation)
    end

    it "refuse la suppression d'une ligne sur un avoir émis (422), aucune suppression" do
      avoir = create(:avoir, :emise, organisation: organisation)
      ligne = avoir.lignes_avoir.first

      expect do
        delete "/api/v1/avoirs/#{avoir.id}/lignes/#{ligne.id}"
      end.not_to change(LigneAvoir, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(LigneAvoir.exists?(ligne.id)).to be(true)
    end
  end
end
