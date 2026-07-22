# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::TransmissionsPa", type: :request do
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
    facture = create(:facture, :emise)

    post "/api/v1/factures/#{facture.id}/transmissions"

    expect(response).to have_http_status(:unauthorized)
  end

  describe "isolation tenant" do
    let(:organisation_a) { create(:organisation) }
    let(:organisation_b) { create(:organisation) }
    let(:utilisateur_a) { create(:utilisateur, organisation: organisation_a) }

    before do
      authenticate_as(utilisateur_a, organisation_a)
    end

    it "empêche de transmettre une facture d'une autre organisation, sans effet de bord" do
      facture_b = create(:facture, :emise, organisation: organisation_b)

      compte_avant = TransmissionPa.count

      post "/api/v1/factures/#{facture_b.id}/transmissions"

      expect(response).to have_http_status(:not_found)
      expect(TransmissionPa.count).to eq(compte_avant)
    end
  end

  describe "transmission d'une facture émise (sandbox)" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation) }
    let!(:plateforme) { create(:plateforme_agreee, organisation: organisation) }
    let(:facture) { create(:facture, :emise, organisation: organisation) }

    before do
      authenticate_as(utilisateur, organisation)
    end

    it "crée une transmission accusée, dépose la facture, et journalise UN événement marqué simulation" do
      compte_transmissions_avant = TransmissionPa.count
      compte_evenements_avant = EvenementFacture.count

      post "/api/v1/factures/#{facture.id}/transmissions"

      expect(response).to have_http_status(:created)
      expect(TransmissionPa.count).to eq(compte_transmissions_avant + 1)
      expect(EvenementFacture.count).to eq(compte_evenements_avant + 1)

      body = JSON.parse(response.body)
      expect(body["statut"]).to eq("depose")
      expect(body["external_id"]).to start_with("SANDBOX-")
      expect(body["simulation"]).to be(true)

      facture.reload
      expect(facture.statut).to eq("deposee")

      evenement = EvenementFacture.order(:created_at).last
      expect(evenement.source).to eq("sandbox")
      expect(evenement.statut).to eq("deposee")
      expect(evenement.payload["simulation"]).to be(true)
      expect(evenement.payload["external_id"]).to eq(body["external_id"])
    end

    it "n'expose ni credentials, ni payload brut non filtré, ni pdf_url/xml_url" do
      post "/api/v1/factures/#{facture.id}/transmissions"

      expect(response.body).not_to include("credentials_chiffres")
      expect(response.body).not_to include(".pdf")
      expect(response.body).not_to include(".xml")
    end

    it "dérive un external_id déterministe depuis l'idempotency_key (rejeu sûr)" do
      post "/api/v1/factures/#{facture.id}/transmissions"
      premier_external_id = JSON.parse(response.body)["external_id"]

      transmission = TransmissionPa.last
      resultat_rejoue = Pa::SandboxPaAdapter.new.submit(facture: facture, transmission: transmission)

      expect(resultat_rejoue.external_id).to eq(premier_external_id)
    end

    it "idempotence : un 2e appel ne crée ni doublon de transmission ni doublon d'événement, renvoie 200" do
      post "/api/v1/factures/#{facture.id}/transmissions"
      premiere_transmission_id = JSON.parse(response.body)["id"]

      compte_transmissions_avant = TransmissionPa.count
      compte_evenements_avant = EvenementFacture.count

      post "/api/v1/factures/#{facture.id}/transmissions"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["id"]).to eq(premiere_transmission_id)
      expect(TransmissionPa.count).to eq(compte_transmissions_avant)
      expect(EvenementFacture.count).to eq(compte_evenements_avant)
    end

    it "échec technique : la transmission passe en erreur, la facture reste INCHANGÉE, AUCUN événement n'est créé" do
      allow(Pa::AdapterFactory).to receive(:for)
        .and_return(Pa::SandboxPaAdapter.new(simulate_network_error: true))

      compte_evenements_avant = EvenementFacture.count

      post "/api/v1/factures/#{facture.id}/transmissions"

      expect(response).to have_http_status(:bad_gateway)
      expect(EvenementFacture.count).to eq(compte_evenements_avant)

      facture.reload
      expect(facture.statut).to eq("emise")

      transmission = TransmissionPa.last
      expect(transmission.statut).to eq("erreur")
      expect(transmission.tentative).to eq(2)
      expect(transmission.message_erreur).to be_present
    end

    it "retry après échec : une nouvelle tentative est possible et aboutit à un dépôt" do
      allow(Pa::AdapterFactory).to receive(:for)
        .and_return(Pa::SandboxPaAdapter.new(simulate_network_error: true))

      post "/api/v1/factures/#{facture.id}/transmissions"
      expect(TransmissionPa.last.statut).to eq("erreur")

      allow(Pa::AdapterFactory).to receive(:for).and_call_original

      compte_transmissions_avant = TransmissionPa.count

      post "/api/v1/factures/#{facture.id}/transmissions"

      expect(response).to have_http_status(:created)
      expect(TransmissionPa.count).to eq(compte_transmissions_avant + 1)
      expect(TransmissionPa.order(:created_at).last.statut).to eq("depose")

      facture.reload
      expect(facture.statut).to eq("deposee")
    end

    it "non-éligibilité : une facture en brouillon ne peut pas être transmise" do
      brouillon = create(:facture, :avec_ligne, organisation: organisation)

      compte_avant = TransmissionPa.count

      post "/api/v1/factures/#{brouillon.id}/transmissions"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(TransmissionPa.count).to eq(compte_avant)
    end

    it "non-éligibilité : aucune plateforme agréée configurée pour l'organisation" do
      plateforme.destroy!
      facture_sans_pa = create(:facture, :emise, organisation: organisation)

      compte_avant = TransmissionPa.count

      post "/api/v1/factures/#{facture_sans_pa.id}/transmissions"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(TransmissionPa.count).to eq(compte_avant)
    end

    it "auditabilité : une requête SQL simple sépare les événements sandbox des événements réels" do
      post "/api/v1/factures/#{facture.id}/transmissions"

      autre_facture = create(:facture, organisation: organisation)
      EvenementFacture.create!(
        organisation: organisation,
        facture: autre_facture,
        utilisateur: utilisateur,
        statut: "brouillon",
        source: "interne",
        payload: { action: "facture_creee" }
      )

      evenements_sandbox = EvenementFacture.where(source: "sandbox")
      evenements_reels = EvenementFacture.where.not(source: "sandbox")

      expect(evenements_sandbox.count).to eq(1)
      expect(evenements_sandbox.first.payload["simulation"]).to be(true)
      expect(evenements_reels.count).to eq(1)
    end

    it "préserve le CHECK XOR facture/avoir : aucune transmission d'avoir n'est tentée ni possible sans document" do
      expect do
        TransmissionPa.create!(
          organisation: organisation,
          plateforme_agreee: plateforme,
          direction: "sortant",
          statut: "en_attente",
          format: "factur_x",
          tentative: 1,
          idempotency_key: SecureRandom.uuid
        )
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "l'événement sandbox reste append-only : ni modifiable ni supprimable" do
      post "/api/v1/factures/#{facture.id}/transmissions"

      evenement = EvenementFacture.last

      expect(evenement.update(statut: "recue")).to be(false)
      expect { evenement.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
    end
  end
end
