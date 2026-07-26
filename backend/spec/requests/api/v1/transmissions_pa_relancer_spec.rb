# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::TransmissionsPa#relancer", type: :request do
  def authenticate_as(utilisateur, organisation)
    allow_any_instance_of(Api::V1::BaseController)
      .to receive(:authenticate_request!) do
        Current.organisation = organisation
        Current.utilisateur = utilisateur
        Current.session = nil
      end
  end

  def relancer(facture)
    post "/api/v1/factures/#{facture.id}/transmissions/relancer"
  end

  after do
    Current.reset
  end

  it "refuse l'accès sans authentification" do
    facture = create(:facture, :deposee)

    relancer(facture)

    expect(response).to have_http_status(:unauthorized)
  end

  describe "isolation tenant" do
    let(:organisation_a) { create(:organisation) }
    let(:organisation_b) { create(:organisation) }
    let(:utilisateur_a) { create(:utilisateur, organisation: organisation_a) }

    before { authenticate_as(utilisateur_a, organisation_a) }

    it "empêche de relancer la transmission d'une autre organisation (404, policy_scope)" do
      facture_b = create(:facture, :deposee, organisation: organisation_b)
      transmission_b = create(
        :transmission_pa, :depose,
        organisation: organisation_b, facture: facture_b,
        polling_paused_at: Time.current
      )

      relancer(facture_b)

      expect(response).to have_http_status(:not_found)
      transmission_b.reload
      expect(transmission_b.polling_paused_at).to be_present
    end
  end

  describe "avec une organisation authentifiée" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation) }
    let!(:plateforme) { create(:plateforme_agreee, organisation: organisation) }
    let(:facture) { create(:facture, :deposee, organisation: organisation) }

    before { authenticate_as(utilisateur, organisation) }

    it "1. RELANCE OK : remet à zéro les champs techniques, ne touche AUCUN statut, ne crée AUCUN événement" do
      transmission = create(
        :transmission_pa, :depose,
        organisation: organisation, facture: facture, plateforme_agreee: plateforme,
        polling_paused_at: Time.current,
        consecutive_poll_errors: 5,
        poll_backoff_step: 3,
        next_poll_at: nil
      )

      compte_evenements_avant = EvenementFacture.count
      compte_entrant_avant = EvenementEntrantPa.count

      relancer(facture)

      expect(response).to have_http_status(:ok)

      transmission.reload
      expect(transmission.polling_paused_at).to be_nil
      expect(transmission.consecutive_poll_errors).to eq(0)
      expect(transmission.poll_backoff_step).to eq(0)
      expect(transmission.next_poll_at).to be_present
      expect(transmission.statut).to eq("depose")

      facture.reload
      expect(facture.statut).to eq("deposee")

      expect(EvenementFacture.count).to eq(compte_evenements_avant)
      expect(EvenementEntrantPa.count).to eq(compte_entrant_avant)
    end

    it "2. RELANCE KO : une transmission NON en pause (active) renvoie 422, pas de double relance" do
      transmission = create(
        :transmission_pa, :depose,
        organisation: organisation, facture: facture, plateforme_agreee: plateforme,
        polling_paused_at: nil,
        next_poll_at: 5.minutes.from_now
      )

      relancer(facture)

      expect(response).to have_http_status(:unprocessable_entity)
      transmission.reload
      expect(transmission.polling_paused_at).to be_nil
    end

    it "3. RELANCE KO : une transmission STOPPÉE définitivement renvoie 422" do
      create(
        :transmission_pa, :depose,
        organisation: organisation, facture: facture, plateforme_agreee: plateforme,
        polling_paused_at: Time.current,
        polling_stopped_at: Time.current,
        polling_stop_reason: "facture_terminale"
      )

      relancer(facture)

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["error"]).to be_present
    end

    it "4. RELANCE KO : aucune transmission déposée à relancer pour cette facture" do
      relancer(facture)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "5. POLICY : rôle+tenant seulement, pas d'éligibilité métier dans la policy (422, pas 403)" do
      create(
        :transmission_pa, :depose,
        organisation: organisation, facture: facture, plateforme_agreee: plateforme,
        polling_paused_at: nil
      )

      relancer(facture)

      expect(response).not_to have_http_status(:forbidden)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "n'expose ni credentials, ni payload brut, et expose bien last_polled_at/consecutive_poll_errors" do
      create(
        :transmission_pa, :depose,
        organisation: organisation, facture: facture, plateforme_agreee: plateforme,
        polling_paused_at: Time.current,
        last_polled_at: 10.minutes.ago,
        consecutive_poll_errors: 2
      )

      relancer(facture)

      expect(response.body).not_to include("credentials_chiffres")
      expect(response.body).not_to include("accuse_reception")

      body = JSON.parse(response.body)
      expect(body).to have_key("last_polled_at")
      expect(body).to have_key("consecutive_poll_errors")
      expect(body["consecutive_poll_errors"]).to eq(0)
    end
  end
end
