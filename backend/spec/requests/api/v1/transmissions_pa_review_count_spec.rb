# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::TransmissionsPa#review_count", type: :request do
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

  it "refuse l'accès sans authentification" do
    get "/api/v1/transmissions_pa/review_count"

    expect(response).to have_http_status(:unauthorized)
  end

  describe "avec une organisation authentifiée" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation) }

    before { authenticate_as(utilisateur, organisation) }

    it "renvoie 0 quand il n'y a aucun requires_review" do
      get "/api/v1/transmissions_pa/review_count"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["requires_review_count"]).to eq(0)
    end

    it "renvoie le compte scopé à l'organisation courante (délègue à PaRequiresReviewCounter)" do
      facture = create(:facture, :deposee, organisation: organisation)
      transmission = create(:transmission_pa, :depose, organisation: organisation, facture: facture)
      create(
        :evenement_entrant_pa,
        organisation: organisation,
        transmission_pa: transmission,
        facture: facture,
        resultat: "requires_review",
        occurred_at: Time.current,
        received_at: Time.current
      )

      autre_organisation = create(:organisation)
      autre_facture = create(:facture, :deposee, organisation: autre_organisation)
      autre_transmission = create(:transmission_pa, :depose, organisation: autre_organisation, facture: autre_facture)
      create(
        :evenement_entrant_pa,
        organisation: autre_organisation,
        transmission_pa: autre_transmission,
        facture: autre_facture,
        resultat: "requires_review",
        occurred_at: Time.current,
        received_at: Time.current
      )

      get "/api/v1/transmissions_pa/review_count"

      expect(JSON.parse(response.body)["requires_review_count"]).to eq(1)
    end
  end
end
