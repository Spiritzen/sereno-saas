# frozen_string_literal: true

require "rails_helper"

# Gabarit littéral de lignes_avoir_spec.rb, adapté au devis. Immutabilité
# après ENVOI (pas après émission — un devis n'émet rien) : 422 (erreur de
# validation modèle), jamais 403 — LigneDevisPolicy ne porte aucune règle
# d'état (cf. commentaire du fichier).
RSpec.describe "Api::V1::LignesDevis", type: :request do
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
      ligne_devis: {
        designation: "Prestation devis",
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

    it "empêche d'ajouter une ligne au devis d'une autre organisation (404)" do
      devis_b = create(:devis, organisation: organisation_b, client: create(:client, organisation: organisation_b))

      expect do
        post "/api/v1/devis/#{devis_b.id}/lignes", params: ligne_params
      end.not_to change(LigneDevis, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "empêche de modifier une ligne appartenant au devis d'une autre organisation (404)" do
      devis_b = create(:devis, organisation: organisation_b, client: create(:client, organisation: organisation_b))
      ligne_b = create(:ligne_devis, devis: devis_b, organisation: organisation_b)

      patch "/api/v1/devis/#{devis_b.id}/lignes/#{ligne_b.id}", params: ligne_params(
        designation: "Tentative cross-tenant"
      )

      expect(response).to have_http_status(:not_found)
      expect(ligne_b.reload.designation).not_to eq("Tentative cross-tenant")
    end

    it "empêche de supprimer une ligne appartenant au devis d'une autre organisation (404)" do
      devis_b = create(:devis, organisation: organisation_b, client: create(:client, organisation: organisation_b))
      ligne_b = create(:ligne_devis, devis: devis_b, organisation: organisation_b)

      expect do
        delete "/api/v1/devis/#{devis_b.id}/lignes/#{ligne_b.id}"
      end.not_to change(LigneDevis, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "lignes sur devis brouillon (T-LIGNE-CREATE / UPDATE / DELETE, T-TOTAUX-BACKEND)" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }
    let(:client) { create(:client, organisation: organisation) }

    before { authenticate_as(utilisateur, organisation) }

    it "T-LIGNE-CREATE : ajoute une ligne, recalcule les totaux CÔTÉ BACKEND (via FactureTotalsService)" do
      devis = create(:devis, organisation: organisation, client: client)

      expect do
        post "/api/v1/devis/#{devis.id}/lignes", params: ligne_params
      end.to change(LigneDevis, :count).by(1)

      expect(response).to have_http_status(:created)

      devis.reload
      expect(devis.total_ht).to eq(BigDecimal("300.00")) # 2 * 150
      expect(devis.total_ttc).to be > devis.total_ht

      body = JSON.parse(response.body)
      expect(body["total_ht"].to_f).to eq(300.0)
    end

    it "T-TOTAUX-BACKEND (décisif) : un total envoyé par le client dans le payload est ignoré" do
      devis = create(:devis, organisation: organisation, client: client)

      post "/api/v1/devis/#{devis.id}/lignes", params: ligne_params(total_ht: 999_999)

      expect(response).to have_http_status(:created)
      devis.reload
      expect(devis.total_ht).to eq(BigDecimal("300.00"))
    end

    it "T-LIGNE-UPDATE : modifie une ligne et recalcule les totaux" do
      devis = create(:devis, organisation: organisation, client: client)
      ligne = create(:ligne_devis, devis: devis, organisation: organisation, quantite: 1, prix_unitaire_ht: 100)
      devis.reload

      patch "/api/v1/devis/#{devis.id}/lignes/#{ligne.id}", params: ligne_params(
        designation: "Modifiée", quantite: 3, prix_unitaire_ht: 100
      )

      expect(response).to have_http_status(:ok)
      ligne.reload
      expect(ligne.designation).to eq("Modifiée")

      devis.reload
      expect(devis.total_ht).to eq(BigDecimal("300.00"))
    end

    it "T-LIGNE-DELETE : supprime une ligne et recalcule les totaux" do
      devis = create(:devis, organisation: organisation, client: client)
      ligne_1 = create(:ligne_devis, devis: devis, organisation: organisation, quantite: 1, prix_unitaire_ht: 100)
      create(:ligne_devis, devis: devis, organisation: organisation, quantite: 1, prix_unitaire_ht: 50)
      devis.reload
      expect(devis.total_ht).to eq(BigDecimal("150.00"))

      expect do
        delete "/api/v1/devis/#{devis.id}/lignes/#{ligne_1.id}"
      end.to change(LigneDevis, :count).by(-1)

      expect(response).to have_http_status(:ok)
      devis.reload
      expect(devis.total_ht).to eq(BigDecimal("50.00"))
    end
  end

  describe "T-LIGNE-IMMUABLE (décisif) : devis déjà envoyé" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }
    let(:client) { create(:client, organisation: organisation) }

    before { authenticate_as(utilisateur, organisation) }

    def devis_envoye
      devis = create(:devis, :avec_ligne, organisation: organisation, client: client)
      DevisStatutService.new(devis: devis, utilisateur: utilisateur).envoyer!
      devis.reload
    end

    it "refuse l'ajout d'une ligne sur un devis envoyé (422, pas 403), aucune ligne créée" do
      devis = devis_envoye

      expect do
        post "/api/v1/devis/#{devis.id}/lignes", params: ligne_params
      end.not_to change(LigneDevis, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "refuse la modification d'une ligne sur un devis envoyé (422), aucun changement" do
      devis = devis_envoye
      ligne = devis.lignes_devis.first
      ancienne_designation = ligne.designation

      patch "/api/v1/devis/#{devis.id}/lignes/#{ligne.id}", params: ligne_params(
        designation: "Modification interdite"
      )

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ligne.reload.designation).to eq(ancienne_designation)
    end

    it "refuse la suppression d'une ligne sur un devis envoyé (422), aucune suppression" do
      devis = devis_envoye
      ligne = devis.lignes_devis.first

      expect do
        delete "/api/v1/devis/#{devis.id}/lignes/#{ligne.id}"
      end.not_to change(LigneDevis, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(LigneDevis.exists?(ligne.id)).to be(true)
    end
  end
end
