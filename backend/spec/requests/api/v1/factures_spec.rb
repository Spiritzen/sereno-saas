# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Factures", type: :request do
  describe "isolation tenant" do
    let(:organisation_a) { create(:organisation) }
    let(:organisation_b) { create(:organisation) }

    let(:utilisateur_a) { create(:utilisateur, organisation: organisation_a) }

    let(:facture_a) { create(:facture, :avec_ligne, organisation: organisation_a) }
    let(:facture_b) { create(:facture, :avec_ligne, organisation: organisation_b) }

    before do
      allow_any_instance_of(Api::V1::BaseController)
        .to receive(:authenticate_request!) do
          Current.organisation = organisation_a
          Current.utilisateur = utilisateur_a
          Current.session = nil
        end
    end

    after do
      Current.reset
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
end
