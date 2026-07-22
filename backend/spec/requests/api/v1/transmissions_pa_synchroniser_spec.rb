# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::TransmissionsPa#synchroniser", type: :request do
  def authenticate_as(utilisateur, organisation)
    allow_any_instance_of(Api::V1::BaseController)
      .to receive(:authenticate_request!) do
        Current.organisation = organisation
        Current.utilisateur = utilisateur
        Current.session = nil
      end
  end

  def synchroniser(facture)
    post "/api/v1/factures/#{facture.id}/transmissions/synchroniser"
  end

  def stub_adapter(adapter)
    allow(Pa::AdapterFactory).to receive(:for).and_return(adapter)
  end

  after do
    Current.reset
  end

  it "refuse l'accès sans authentification" do
    facture = create(:facture, :deposee)

    synchroniser(facture)

    expect(response).to have_http_status(:unauthorized)
  end

  describe "isolation tenant" do
    let(:organisation_a) { create(:organisation) }
    let(:organisation_b) { create(:organisation) }
    let(:utilisateur_a) { create(:utilisateur, organisation: organisation_a) }

    before { authenticate_as(utilisateur_a, organisation_a) }

    it "empêche de synchroniser la facture d'une autre organisation, sans effet de bord" do
      facture_b = create(:facture, :deposee, organisation: organisation_b)
      create(:transmission_pa, :depose, organisation: organisation_b, facture: facture_b)

      compte_entrant_avant = EvenementEntrantPa.count

      synchroniser(facture_b)

      expect(response).to have_http_status(:not_found)
      expect(EvenementEntrantPa.count).to eq(compte_entrant_avant)
    end
  end

  describe "synchronisation d'une facture déposée (sandbox)" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation) }
    let!(:plateforme) { create(:plateforme_agreee, organisation: organisation) }
    let(:facture) { create(:facture, :deposee, organisation: organisation) }
    let!(:transmission) do
      create(:transmission_pa, :depose, organisation: organisation, facture: facture, plateforme_agreee: plateforme)
    end

    before { authenticate_as(utilisateur, organisation) }

    it "1. PROGRESSION : deposee -> recue -> mise_a_disposition -> approuvee, un événement par étape" do
      compte_evenements_avant = EvenementFacture.count

      synchroniser(facture)
      body = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)
      expect(body["resultat"]).to eq("applied")
      expect(body["statut_facture_apres"]).to eq("recue")
      facture.reload
      expect(facture.statut).to eq("recue")
      expect(EvenementFacture.count).to eq(compte_evenements_avant + 1)

      dernier_evenement = EvenementFacture.order(:created_at).last
      expect(dernier_evenement.source).to eq("sandbox")
      expect(dernier_evenement.payload["simulation"]).to be(true)

      synchroniser(facture)
      expect(JSON.parse(response.body)["statut_facture_apres"]).to eq("mise_a_disposition")
      facture.reload
      expect(facture.statut).to eq("mise_a_disposition")
      expect(EvenementFacture.count).to eq(compte_evenements_avant + 2)

      synchroniser(facture)
      expect(JSON.parse(response.body)["statut_facture_apres"]).to eq("approuvee")
      facture.reload
      expect(facture.statut).to eq("approuvee")
      expect(EvenementFacture.count).to eq(compte_evenements_avant + 3)

      expect(EvenementEntrantPa.where(transmission_pa: transmission).count).to eq(3)
    end

    it "2. DOUBLON : la même notification 2 fois -> 1 seul EvenementEntrantPa, 0 nouvel EvenementFacture" do
      stub_adapter(Pa::SandboxPaAdapter.new(fetch_status_scenario: :duplicate))

      synchroniser(facture)
      expect(JSON.parse(response.body)["resultat"]).to eq("applied")

      compte_entrant_avant = EvenementEntrantPa.count
      compte_evenements_avant = EvenementFacture.count

      synchroniser(facture)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["resultat"]).to eq("duplicate")
      expect(EvenementEntrantPa.count).to eq(compte_entrant_avant)
      expect(EvenementFacture.count).to eq(compte_evenements_avant)
      facture.reload
      expect(facture.statut).to eq("recue")
    end

    it "3. GARDE TEMPORELLE : un message en retard n'annule pas un en_litige plus récent" do
      sequence = %w[SANDBOX_APPROVED SANDBOX_DISPUTED SANDBOX_APPROVED]

      stub_adapter(Pa::SandboxPaAdapter.new(fetch_status_sequence: sequence))
      synchroniser(facture) # deposee -> approuvee
      expect(JSON.parse(response.body)["resultat"]).to eq("applied")

      stub_adapter(Pa::SandboxPaAdapter.new(fetch_status_sequence: sequence))
      synchroniser(facture) # approuvee -> en_litige
      expect(JSON.parse(response.body)["resultat"]).to eq("applied")
      facture.reload
      expect(facture.statut).to eq("en_litige")

      compte_evenements_avant = EvenementFacture.count

      stub_adapter(
        Pa::SandboxPaAdapter.new(fetch_status_sequence: sequence, fetch_status_scenario: :out_of_order)
      )
      synchroniser(facture) # message tardif : "approuvee" avec l'occurred_at du tout premier appel

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["resultat"]).to eq("stale")

      facture.reload
      expect(facture.statut).to eq("en_litige")
      expect(EvenementFacture.count).to eq(compte_evenements_avant)
    end

    it "4. RÉGRESSION SIMPLE : une notification récente mais régressive reste sans effet" do
      sequence = %w[SANDBOX_APPROVED SANDBOX_RECEIVED]
      stub_adapter(Pa::SandboxPaAdapter.new(fetch_status_sequence: sequence))

      synchroniser(facture) # deposee -> approuvee
      expect(JSON.parse(response.body)["resultat"]).to eq("applied")

      compte_evenements_avant = EvenementFacture.count

      synchroniser(facture) # "recue", plus récent, mais approuvee -> recue n'est pas dans la table

      expect(JSON.parse(response.body)["resultat"]).to eq("stale")
      facture.reload
      expect(facture.statut).to eq("approuvee")
      expect(EvenementFacture.count).to eq(compte_evenements_avant)
    end

    it "5. CONTRADICTION : une notification depuis un statut terminal est signalée, pas appliquée" do
      sequence = %w[SANDBOX_APPROVED SANDBOX_PAID SANDBOX_REJECTED]
      stub_adapter(Pa::SandboxPaAdapter.new(fetch_status_sequence: sequence))

      synchroniser(facture) # deposee -> approuvee
      synchroniser(facture) # approuvee -> encaissee
      facture.reload
      expect(facture.statut).to eq("encaissee")

      compte_evenements_avant = EvenementFacture.count

      synchroniser(facture) # "refusee" depuis encaissee (terminal)

      body = JSON.parse(response.body)
      expect(body["resultat"]).to eq("requires_review")
      expect(body["motif"]).to be_present

      facture.reload
      expect(facture.statut).to eq("encaissee")
      expect(EvenementFacture.count).to eq(compte_evenements_avant)

      evenement_entrant = EvenementEntrantPa.order(:created_at).last
      expect(evenement_entrant.resultat).to eq("requires_review")
      expect(evenement_entrant.motif).to be_present
    end

    it "6. UNMAPPED : un statut fournisseur inconnu est conservé sans effet" do
      stub_adapter(Pa::SandboxPaAdapter.new(fetch_status_scenario: :unmapped))

      compte_evenements_avant = EvenementFacture.count

      synchroniser(facture)

      body = JSON.parse(response.body)
      expect(body["resultat"]).to eq("unmapped")

      facture.reload
      expect(facture.statut).to eq("deposee")
      expect(EvenementFacture.count).to eq(compte_evenements_avant)

      evenement_entrant = EvenementEntrantPa.order(:created_at).last
      expect(evenement_entrant.statut_candidat).to be_nil
      expect(evenement_entrant.statut_brut).to eq("SANDBOX_STATUS_INCONNU")
    end

    it "7. SAUT AVANT : deposee -> approuvee directement, sans inventer recue ni mise_a_disposition" do
      stub_adapter(Pa::SandboxPaAdapter.new(fetch_status_sequence: %w[SANDBOX_APPROVED]))

      compte_evenements_avant = EvenementFacture.count

      synchroniser(facture)

      body = JSON.parse(response.body)
      expect(body["resultat"]).to eq("applied")
      expect(body["statut_facture_apres"]).to eq("approuvee")

      facture.reload
      expect(facture.statut).to eq("approuvee")
      expect(EvenementFacture.count).to eq(compte_evenements_avant + 1)

      statuts_evenements = EvenementFacture.where(facture: facture).pluck(:statut)
      expect(statuts_evenements).to eq([ "approuvee" ])
      expect(statuts_evenements).not_to include("recue", "mise_a_disposition")
    end

    it "8. ÉCHEC TECHNIQUE : aucune donnée écrite, la facture reste intacte, 502" do
      stub_adapter(Pa::SandboxPaAdapter.new(simulate_network_error: true))

      compte_entrant_avant = EvenementEntrantPa.count
      compte_evenements_avant = EvenementFacture.count

      synchroniser(facture)

      expect(response).to have_http_status(:bad_gateway)
      expect(EvenementEntrantPa.count).to eq(compte_entrant_avant)
      expect(EvenementFacture.count).to eq(compte_evenements_avant)

      facture.reload
      expect(facture.statut).to eq("deposee")
    end

    it "11. AUDITABILITÉ : tous les EvenementEntrantPa d'une transmission sont retrouvables, y compris les non-appliqués" do
      sequence = %w[SANDBOX_APPROVED SANDBOX_RECEIVED]
      stub_adapter(Pa::SandboxPaAdapter.new(fetch_status_sequence: sequence))

      synchroniser(facture) # applied : approuvee
      synchroniser(facture) # stale : régression

      evenements = EvenementEntrantPa.where(transmission_pa: transmission).order(:created_at)

      expect(evenements.count).to eq(2)
      expect(evenements.pluck(:resultat)).to eq(%w[applied stale])

      evenements_sandbox = EvenementFacture.where(source: "sandbox")
      expect(evenements_sandbox.count).to eq(1)
    end

    it "non-éligibilité : aucune transmission déposée pour cette facture" do
      transmission.update_columns(statut: "en_attente")

      compte_entrant_avant = EvenementEntrantPa.count

      synchroniser(facture)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(EvenementEntrantPa.count).to eq(compte_entrant_avant)
    end

    it "une facture dans un état terminal reste synchronisable : la contradiction doit rester détectable" do
      facture.update_columns(statut: "encaissee")

      synchroniser(facture) # PA confirme "recue" (index 0) : contradiction depuis un état terminal

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["resultat"]).to eq("requires_review")
      facture.reload
      expect(facture.statut).to eq("encaissee")
    end

    it "n'expose ni credentials, ni payload brut non filtré, ni pdf_url/xml_url" do
      synchroniser(facture)

      expect(response.body).not_to include("credentials_chiffres")
      expect(response.body).not_to include(".pdf")
      expect(response.body).not_to include(".xml")
    end
  end
end
