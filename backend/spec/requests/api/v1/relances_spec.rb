# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Relances", type: :request do
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
    facture = create(:facture, :emise, date_echeance: 1.day.ago)

    post "/api/v1/factures/#{facture.id}/relances"

    expect(response).to have_http_status(:unauthorized)
  end

  describe "T-ISOLATION (décisif)" do
    let(:organisation_a) { create(:organisation) }
    let(:organisation_b) { create(:organisation) }
    let(:utilisateur_b) { create(:utilisateur, organisation: organisation_b, role: "owner") }
    let(:facture_a) { create(:facture, :emise, organisation: organisation_a, date_echeance: 1.day.ago) }

    it "refuse à l'organisation B de relancer une facture de A (404)" do
      authenticate_as(utilisateur_b, organisation_b)

      post "/api/v1/factures/#{facture_a.id}/relances"

      expect(response).to have_http_status(:not_found)
      expect(Relance.count).to eq(0)
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  describe "T-ROLE (rôle non autorisé → 403 ; comptable ET super_admin exclus, exécution du 12/08/2026)" do
    let(:organisation) { create(:organisation) }
    let(:facture) { create(:facture, :emise, organisation: organisation, date_echeance: 1.day.ago) }

    it "refuse à un comptable de relancer (403)" do
      utilisateur_comptable = create(:utilisateur, organisation: organisation, role: "comptable")
      authenticate_as(utilisateur_comptable, organisation)

      post "/api/v1/factures/#{facture.id}/relances"

      expect(response).to have_http_status(:forbidden)
      expect(Relance.count).to eq(0)
    end

    it "refuse à un super_admin de relancer (403) — rôle plateforme, pas un acte métier tenant" do
      utilisateur_super_admin = create(:utilisateur, organisation: organisation, role: "super_admin")
      authenticate_as(utilisateur_super_admin, organisation)

      post "/api/v1/factures/#{facture.id}/relances"

      expect(response).to have_http_status(:forbidden)
      expect(Relance.count).to eq(0)
    end

    it "autorise un membre à relancer (à la différence des paiements)" do
      utilisateur_membre = create(:utilisateur, organisation: organisation, role: "membre")
      authenticate_as(utilisateur_membre, organisation)

      post "/api/v1/factures/#{facture.id}/relances"

      expect(response).to have_http_status(:created)
    end

    it "autorise un owner à relancer" do
      utilisateur_owner = create(:utilisateur, organisation: organisation, role: "owner")
      authenticate_as(utilisateur_owner, organisation)

      post "/api/v1/factures/#{facture.id}/relances"

      expect(response).to have_http_status(:created)
    end
  end

  describe "T-CREATE" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }

    before { authenticate_as(utilisateur, organisation) }

    it "envoie un rappel et journalise la relance sur une facture éligible" do
      facture = create(:facture, :emise, organisation: organisation, date_echeance: 1.day.ago)

      expect {
        post "/api/v1/factures/#{facture.id}/relances"
      }.to change(ActionMailer::Base.deliveries, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)

      expect(body["relance"]["statut"]).to eq("envoyee")
      expect(body["relance"]["destinataire_email"]).to eq(facture.client.email)
      expect(body["relance"]["mode_livraison"]).to eq("test")
      # La relance n'affecte ni le solde ni l'échéance : la facture reste
      # relançable après l'envoi (seul un paiement changerait ceci).
      expect(body["facture"]["relancable"]).to eq(true)
      expect(body["facture"]["derniere_relance_at"]).to be_present
      expect(body["facture"]["relances_count"]).to eq(1)

      expect(Relance.count).to eq(1)
      expect(Relance.first.utilisateur_id).to eq(utilisateur.id)
    end

    it "refuse (422) une facture non éligible, sans effet de bord" do
      facture_brouillon = create(:facture, organisation: organisation)

      expect {
        post "/api/v1/factures/#{facture_brouillon.id}/relances"
      }.not_to change(ActionMailer::Base.deliveries, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Relance.count).to eq(0)
    end

    it "refuse (422) une facture émise mais dont l'échéance n'est pas dépassée" do
      facture = create(:facture, :emise, organisation: organisation, date_echeance: 30.days.from_now)

      post "/api/v1/factures/#{facture.id}/relances"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Relance.count).to eq(0)
    end

    it "refuse (422) une facture déjà entièrement payée" do
      facture = create(:facture, :emise, organisation: organisation, date_echeance: 1.day.ago)
      create(:paiement, :confirme, facture: facture, organisation: organisation, montant: facture.total_ttc)

      post "/api/v1/factures/#{facture.id}/relances"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Relance.count).to eq(0)
    end
  end
end
