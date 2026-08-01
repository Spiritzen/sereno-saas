# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Paiements", type: :request do
  def authenticate_as(utilisateur, organisation)
    allow_any_instance_of(Api::V1::BaseController)
      .to receive(:authenticate_request!) do
        Current.organisation = organisation
        Current.utilisateur = utilisateur
        Current.session = nil
      end
  end

  after { Current.reset }

  it "refuse l'accès sans authentification" do
    facture = create(:facture, :emise)

    get "/api/v1/factures/#{facture.id}/paiements"

    expect(response).to have_http_status(:unauthorized)
  end

  describe "T-ISOLATION (décisif)" do
    let(:organisation_a) { create(:organisation) }
    let(:organisation_b) { create(:organisation) }
    let(:utilisateur_a) { create(:utilisateur, organisation: organisation_a, role: "owner") }
    let(:utilisateur_b) { create(:utilisateur, organisation: organisation_b, role: "owner") }
    let(:facture_a) { create(:facture, :emise, organisation: organisation_a) }
    let!(:paiement_a) { create(:paiement, organisation: organisation_a, facture: facture_a) }

    it "refuse à l'organisation B l'index des paiements de la facture de A (404)" do
      authenticate_as(utilisateur_b, organisation_b)

      get "/api/v1/factures/#{facture_a.id}/paiements"

      expect(response).to have_http_status(:not_found)
    end

    it "ne fait jamais apparaître les paiements de A dans l'index de B sur une facture de B" do
      facture_b = create(:facture, :emise, organisation: organisation_b)
      authenticate_as(utilisateur_b, organisation_b)

      get "/api/v1/factures/#{facture_b.id}/paiements"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.map { |p| p["id"] }).not_to include(paiement_a.id)
    end

    it "refuse de créer un paiement sur une facture d'une autre organisation (404)" do
      authenticate_as(utilisateur_b, organisation_b)

      post "/api/v1/factures/#{facture_a.id}/paiements",
           params: { paiement: { montant: 10, methode_code: "58", date_encaissement: Date.current } }

      expect(response).to have_http_status(:not_found)
      expect(EvenementPaiement.count).to eq(0)
    end

    it "refuse de confirmer un paiement d'une autre organisation (404), sans effet de bord" do
      authenticate_as(utilisateur_b, organisation_b)

      post "/api/v1/factures/#{facture_a.id}/paiements/#{paiement_a.id}/confirmer"

      expect(response).to have_http_status(:not_found)
      expect(paiement_a.reload.statut).to eq("brouillon")
    end

    it "refuse d'annuler un paiement d'une autre organisation (404), sans effet de bord" do
      paiement_a.update_columns(statut: "confirme")
      authenticate_as(utilisateur_b, organisation_b)

      post "/api/v1/factures/#{facture_a.id}/paiements/#{paiement_a.id}/annuler"

      expect(response).to have_http_status(:not_found)
      expect(paiement_a.reload.statut).to eq("confirme")
    end
  end

  describe "T-ROLE (rôle non autorisé → 403, distinct du tenant → 404)" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur_membre) { create(:utilisateur, organisation: organisation, role: "membre") }
    let(:facture) { create(:facture, :emise, organisation: organisation) }

    before { authenticate_as(utilisateur_membre, organisation) }

    it "refuse à un membre la création d'un paiement (403)" do
      post "/api/v1/factures/#{facture.id}/paiements",
           params: { paiement: { montant: 10, methode_code: "58", date_encaissement: Date.current } }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "T-CREATE" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }

    before { authenticate_as(utilisateur, organisation) }

    it "crée un paiement brouillon rattaché à une facture émise, avec son événement" do
      facture = create(:facture, :emise, organisation: organisation)

      post "/api/v1/factures/#{facture.id}/paiements",
           params: { paiement: { montant: 40, methode_code: "58", date_encaissement: Date.current, reference: "VIR-1" } }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["statut"]).to eq("brouillon")
      expect(body["methode_code"]).to eq("58")
      expect(body["methode_libelle"]).to eq("Virement SEPA")
      expect(body["facture_id"]).to eq(facture.id)

      paiement = Paiement.find(body["id"])
      expect(paiement.evenements_paiement.count).to eq(1)
      expect(paiement.evenements_paiement.first.statut).to eq("brouillon")
    end

    it "refuse de créer un paiement sur une facture encore en brouillon (422, pas 403)" do
      facture_brouillon = create(:facture, organisation: organisation)

      post "/api/v1/factures/#{facture_brouillon.id}/paiements",
           params: { paiement: { montant: 40, methode_code: "58", date_encaissement: Date.current } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Paiement.count).to eq(0)
      expect(EvenementPaiement.count).to eq(0)
    end

    it "refuse un methode_code hors nomenclature 4461 (422)" do
      facture = create(:facture, :emise, organisation: organisation)

      post "/api/v1/factures/#{facture.id}/paiements",
           params: { paiement: { montant: 40, methode_code: "99", date_encaissement: Date.current } }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "T-CONFIRMER / T-ANNULER" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }
    let(:facture) { create(:facture, :emise, organisation: organisation) }

    before { authenticate_as(utilisateur, organisation) }

    it "confirme un paiement brouillon et journalise l'événement" do
      paiement = create(:paiement, organisation: organisation, facture: facture)

      post "/api/v1/factures/#{facture.id}/paiements/#{paiement.id}/confirmer"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["statut"]).to eq("confirme")
      expect(paiement.evenements_paiement.count).to eq(1)
    end

    it "annule un paiement confirmé (jamais un destroy)" do
      paiement = create(:paiement, :confirme, organisation: organisation, facture: facture)

      post "/api/v1/factures/#{facture.id}/paiements/#{paiement.id}/annuler"

      expect(response).to have_http_status(:ok)
      expect(Paiement.exists?(paiement.id)).to be(true)
      expect(paiement.reload.statut).to eq("annule")
    end

    it "refuse d'annuler un paiement encore brouillon (transition interdite, 422)" do
      paiement = create(:paiement, organisation: organisation, facture: facture)

      post "/api/v1/factures/#{facture.id}/paiements/#{paiement.id}/annuler"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(paiement.reload.statut).to eq("brouillon")
    end

    it "refuse de confirmer deux fois (transition confirme -> confirme interdite, 422)" do
      paiement = create(:paiement, :confirme, organisation: organisation, facture: facture)

      post "/api/v1/factures/#{facture.id}/paiements/#{paiement.id}/confirmer"

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "T-BLUEPRINT (aucune fuite)" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }
    let(:facture) { create(:facture, :emise, organisation: organisation) }
    let!(:paiement) { create(:paiement, organisation: organisation, facture: facture) }

    before { authenticate_as(utilisateur, organisation) }

    it "n'expose jamais l'email de l'acteur dans les événements d'un paiement" do
      create(:evenement_paiement, organisation: organisation, paiement: paiement, utilisateur: utilisateur)

      get "/api/v1/factures/#{facture.id}/paiements/#{paiement.id}/evenements"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(utilisateur.email)
    end

    it "n'expose pas de champ interne superflu sur l'index des paiements" do
      get "/api/v1/factures/#{facture.id}/paiements"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.first.keys).to contain_exactly(
        "id", "facture_id", "montant", "methode_code", "reference", "statut",
        "methode_libelle", "date_encaissement", "created_at", "updated_at"
      )
    end
  end

  describe "T-SYNTHESE (dérivée, jamais stockée, distincte de facture.statut)" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }

    before { authenticate_as(utilisateur, organisation) }

    it "expose reste_a_payer et statut_encaissement_local sur la facture, à jour après confirmation" do
      facture = create(:facture, :emise, organisation: organisation)
      facture.update_columns(total_ttc: 100)

      get "/api/v1/factures/#{facture.id}"
      body = JSON.parse(response.body)
      expect(body["reste_a_payer"]).to eq("100.0")
      expect(body["statut_encaissement_local"]).to eq("non_payee")
      expect(body["statut"]).to eq("emise")

      paiement = create(:paiement, organisation: organisation, facture: facture, montant: 40)
      post "/api/v1/factures/#{facture.id}/paiements/#{paiement.id}/confirmer"

      get "/api/v1/factures/#{facture.id}"
      body = JSON.parse(response.body)
      expect(body["reste_a_payer"]).to eq("60.0")
      expect(body["statut_encaissement_local"]).to eq("partielle")
      # facture.statut (cycle de vie/transmission) reste totalement indépendant
      expect(body["statut"]).to eq("emise")
      expect(facture.reload.montant_paye).to eq(0)
    end
  end
end
