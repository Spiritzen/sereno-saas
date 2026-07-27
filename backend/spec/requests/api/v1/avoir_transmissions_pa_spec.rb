# frozen_string_literal: true

require "rails_helper"

# V1.2c — gabarit littéral de transmissions_pa_spec.rb (facture), adapté à
# l'avoir : mêmes garanties (isolation, idempotence, non-fuite, XOR,
# append-only), preuve que le couloir généralisé (TransmissionPaOrchestration
# Service / PaStatusIngestionService) traite l'avoir sans dupliquer une
# seule règle et sans jamais régresser côté facture (cf. specs facture,
# inchangées, toujours vertes).
RSpec.describe "Api::V1::AvoirTransmissionsPa", type: :request do
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
    avoir = create(:avoir, :emise)

    post "/api/v1/avoirs/#{avoir.id}/transmissions"

    expect(response).to have_http_status(:unauthorized)
  end

  describe "T-ISOLATION (décisif)" do
    let(:organisation_a) { create(:organisation) }
    let(:organisation_b) { create(:organisation) }
    let(:utilisateur_a) { create(:utilisateur, organisation: organisation_a, role: "owner") }

    before { authenticate_as(utilisateur_a, organisation_a) }

    it "empêche de transmettre l'avoir d'une autre organisation, sans effet de bord (404)" do
      avoir_b = create(:avoir, :emise, organisation: organisation_b)

      compte_avant = TransmissionPa.count

      post "/api/v1/avoirs/#{avoir_b.id}/transmissions"

      expect(response).to have_http_status(:not_found)
      expect(TransmissionPa.count).to eq(compte_avant)
    end

    it "empêche de synchroniser l'avoir d'une autre organisation (404)" do
      avoir_b = create(:avoir, :deposee, organisation: organisation_b)
      create(:transmission_pa, :depose_avoir, organisation: organisation_b, avoir: avoir_b)

      post "/api/v1/avoirs/#{avoir_b.id}/transmissions/synchroniser"

      expect(response).to have_http_status(:not_found)
    end

    it "empêche de lister les transmissions de l'avoir d'une autre organisation (404)" do
      avoir_b = create(:avoir, :emise, organisation: organisation_b)

      get "/api/v1/avoirs/#{avoir_b.id}/transmissions"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "T-TRANSMISSION-AVOIR : dépôt d'un avoir émis (sandbox)" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }
    let!(:plateforme) { create(:plateforme_agreee, organisation: organisation) }
    let(:avoir) { create(:avoir, :emise, organisation: organisation) }

    before { authenticate_as(utilisateur, organisation) }

    it "crée une transmission rattachée à l'avoir (avoir_id), dépose l'avoir, journalise UN evenement_avoir (pas evenement_facture)" do
      compte_transmissions_avant = TransmissionPa.count
      compte_evenements_avoir_avant = EvenementAvoir.count
      compte_evenements_facture_avant = EvenementFacture.count

      post "/api/v1/avoirs/#{avoir.id}/transmissions"

      expect(response).to have_http_status(:created)
      expect(TransmissionPa.count).to eq(compte_transmissions_avant + 1)
      expect(EvenementAvoir.count).to eq(compte_evenements_avoir_avant + 1)
      expect(EvenementFacture.count).to eq(compte_evenements_facture_avant) # inchangé, décisif

      transmission = TransmissionPa.last
      expect(transmission.avoir_id).to eq(avoir.id)
      expect(transmission.facture_id).to be_nil

      body = JSON.parse(response.body)
      expect(body["statut"]).to eq("depose")
      expect(body["external_id"]).to start_with("SANDBOX-")

      avoir.reload
      expect(avoir.statut).to eq("deposee")

      evenement = EvenementAvoir.order(:created_at).last
      expect(evenement.avoir_id).to eq(avoir.id)
      expect(evenement.source).to eq("sandbox")
      expect(evenement.statut).to eq("deposee")
    end

    it "n'expose ni credentials, ni pdf_url/xml_url" do
      post "/api/v1/avoirs/#{avoir.id}/transmissions"

      expect(response.body).not_to include("credentials_chiffres")
      expect(response.body).not_to include(".pdf")
      expect(response.body).not_to include(".xml")
    end

    it "idempotence : un 2e appel ne crée ni doublon de transmission ni doublon d'événement, renvoie 200" do
      post "/api/v1/avoirs/#{avoir.id}/transmissions"
      premiere_transmission_id = JSON.parse(response.body)["id"]

      compte_transmissions_avant = TransmissionPa.count
      compte_evenements_avant = EvenementAvoir.count

      post "/api/v1/avoirs/#{avoir.id}/transmissions"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["id"]).to eq(premiere_transmission_id)
      expect(TransmissionPa.count).to eq(compte_transmissions_avant)
      expect(EvenementAvoir.count).to eq(compte_evenements_avant)
    end

    it "non-éligibilité : un avoir en brouillon ne peut pas être transmis (422)" do
      avoir_brouillon = create(:avoir, organisation: organisation)
      create(:ligne_avoir, avoir: avoir_brouillon, organisation: organisation)

      compte_avant = TransmissionPa.count

      post "/api/v1/avoirs/#{avoir_brouillon.id}/transmissions"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(TransmissionPa.count).to eq(compte_avant)
    end

    it "l'événement de dépôt reste append-only : ni modifiable ni supprimable" do
      post "/api/v1/avoirs/#{avoir.id}/transmissions"

      evenement = EvenementAvoir.last

      expect(evenement.update(statut: "recue")).to be(false)
      expect { evenement.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
    end
  end

  describe "T-INGESTION-AVOIR : synchronisation d'un avoir déposé (sandbox)" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }
    let!(:plateforme) { create(:plateforme_agreee, organisation: organisation) }
    let(:avoir) { create(:avoir, :deposee, organisation: organisation) }
    let!(:transmission) do
      create(:transmission_pa, :depose_avoir, organisation: organisation, avoir: avoir, plateforme_agreee: plateforme)
    end

    before { authenticate_as(utilisateur, organisation) }

    it "applique la transition à l'AVOIR et inscrit un evenement_avoir (jamais un evenement_facture)" do
      compte_evenements_facture_avant = EvenementFacture.count

      post "/api/v1/avoirs/#{avoir.id}/transmissions/synchroniser"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["resultat"]).to eq("applied")
      expect(body["statut_facture_apres"]).to eq("recue")

      avoir.reload
      expect(avoir.statut).to eq("recue")

      evenement_entrant = EvenementEntrantPa.where(avoir: avoir).sole
      expect(evenement_entrant.facture_id).to be_nil

      derniere_ligne_journal = EvenementAvoir.order(:created_at).last
      expect(derniere_ligne_journal.avoir_id).to eq(avoir.id)
      expect(derniere_ligne_journal.statut).to eq("recue")
      expect(EvenementFacture.count).to eq(compte_evenements_facture_avant) # décisif : rien côté facture
    end

    it "doublon : la même notification 2 fois -> 1 seul EvenementEntrantPa, 0 nouvel EvenementAvoir" do
      stub_adapter_duplicate

      post "/api/v1/avoirs/#{avoir.id}/transmissions/synchroniser"
      expect(JSON.parse(response.body)["resultat"]).to eq("applied")

      compte_entrant_avant = EvenementEntrantPa.count
      compte_evenements_avant = EvenementAvoir.count

      post "/api/v1/avoirs/#{avoir.id}/transmissions/synchroniser"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["resultat"]).to eq("duplicate")
      expect(EvenementEntrantPa.count).to eq(compte_entrant_avant)
      expect(EvenementAvoir.count).to eq(compte_evenements_avant)
    end

    def stub_adapter_duplicate
      allow(Pa::AdapterFactory).to receive(:for)
        .and_return(Pa::SandboxPaAdapter.new(fetch_status_scenario: :duplicate))
    end
  end
end
