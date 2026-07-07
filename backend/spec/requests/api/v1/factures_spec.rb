# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Factures", type: :request do
  def authenticate_as(utilisateur, organisation)
    allow_any_instance_of(Api::V1::BaseController)
      .to receive(:authenticate_request!) do
        Current.organisation = organisation
        Current.utilisateur = utilisateur
        Current.session = nil
      end
  end

  after do
    Current.reset
  end

  describe "isolation tenant" do
    let(:organisation_a) { create(:organisation) }
    let(:organisation_b) { create(:organisation) }
    let(:utilisateur_a) { create(:utilisateur, organisation: organisation_a) }

    let(:facture_a) { create(:facture, :avec_ligne, organisation: organisation_a) }
    let(:facture_b) { create(:facture, :avec_ligne, organisation: organisation_b) }

    before do
      authenticate_as(utilisateur_a, organisation_a)
    end

    it "autorise la lecture d'une facture de sa propre organisation" do
      get "/api/v1/factures/#{facture_a.id}"

      expect(response).to have_http_status(:ok)
    end

    it "empêche la lecture d'une facture appartenant à une autre organisation" do
      get "/api/v1/factures/#{facture_b.id}"

      expect(response).to have_http_status(:not_found)
    end

    it "empêche la modification d'une facture appartenant à une autre organisation" do
      patch "/api/v1/factures/#{facture_b.id}", params: {
        facture: {
          mentions: "Tentative cross-tenant"
        }
      }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "garde-fous sur les brouillons" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }

    before do
      authenticate_as(utilisateur, organisation)
    end

    it "autorise la modification d'une facture brouillon" do
      facture = create(:facture, organisation: organisation)
      nouvelle_echeance = 45.days.from_now.to_date

      patch "/api/v1/factures/#{facture.id}", params: {
        facture: {
          date_echeance: nouvelle_echeance,
          mentions: "Mention modifiée sur brouillon"
        }
      }

      expect(response).to have_http_status(:ok)

      facture.reload
      expect(facture.date_echeance).to eq(nouvelle_echeance)
      expect(facture.mentions).to eq("Mention modifiée sur brouillon")
    end

    it "autorise la suppression d'une facture brouillon" do
      facture = create(:facture, :avec_ligne, organisation: organisation)

      delete "/api/v1/factures/#{facture.id}"

      expect(response).to have_http_status(:no_content)
      expect(Facture.exists?(facture.id)).to be(false)
    end
  end

  describe "immutabilité des factures émises" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }

    before do
      authenticate_as(utilisateur, organisation)
    end

    it "refuse la modification d'une facture émise" do
      facture = create(:facture, :emise, organisation: organisation)
      ancienne_echeance = facture.date_echeance
      ancien_numero = facture.numero

      patch "/api/v1/factures/#{facture.id}", params: {
        facture: {
          date_echeance: 60.days.from_now.to_date,
          mentions: "Modification interdite"
        }
      }

      expect(response).to have_http_status(:forbidden)

      facture.reload
      expect(facture.date_echeance).to eq(ancienne_echeance)
      expect(facture.numero).to eq(ancien_numero)
      expect(facture.mentions).not_to eq("Modification interdite")
    end

    it "refuse la suppression d'une facture émise" do
      facture = create(:facture, :emise, organisation: organisation)

      delete "/api/v1/factures/#{facture.id}"

      expect(response).to have_http_status(:forbidden)
      expect(Facture.exists?(facture.id)).to be(true)
    end
  end
end
