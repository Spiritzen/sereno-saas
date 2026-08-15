# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Exports", type: :request do
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
    get "/api/v1/exports/fec", params: { debut: "2026-01-01", fin: "2026-12-31" }

    expect(response).to have_http_status(:unauthorized)
  end

  describe "T-ROLE (owner + comptable ; membre refusé)" do
    let(:organisation) { create(:organisation) }

    it "autorise un owner" do
      utilisateur = create(:utilisateur, organisation: organisation, role: "owner")
      authenticate_as(utilisateur, organisation)

      get "/api/v1/exports/fec", params: { debut: "2026-01-01", fin: "2026-12-31" }

      expect(response).to have_http_status(:ok)
    end

    it "autorise un comptable (c'est son rôle : lecture finance + exports)" do
      utilisateur = create(:utilisateur, organisation: organisation, role: "comptable")
      authenticate_as(utilisateur, organisation)

      get "/api/v1/exports/fec", params: { debut: "2026-01-01", fin: "2026-12-31" }

      expect(response).to have_http_status(:ok)
    end

    it "refuse un membre (403)" do
      utilisateur = create(:utilisateur, organisation: organisation, role: "membre")
      authenticate_as(utilisateur, organisation)

      get "/api/v1/exports/fec", params: { debut: "2026-01-01", fin: "2026-12-31" }

      expect(response).to have_http_status(:forbidden)
    end

    it "refuse un super_admin (rôle plateforme, hors tenant)" do
      utilisateur = create(:utilisateur, organisation: organisation, role: "super_admin")
      authenticate_as(utilisateur, organisation)

      get "/api/v1/exports/fec", params: { debut: "2026-01-01", fin: "2026-12-31" }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/exports/fec/apercu" do
    let(:organisation) { create(:organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }

    before { authenticate_as(utilisateur, organisation) }

    it "renvoie l'étiquette d'honnêteté et le nom de fichier, SANS générer le fichier complet" do
      get "/api/v1/exports/fec/apercu", params: { debut: "2026-01-01", fin: "2026-12-31" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["etiquette"]).to include("reconstitué automatiquement")
      expect(body["etiquette"]).to include("expert-comptable")
      expect(body["nom_fichier"]).to eq("#{organisation.siret[0, 9]}FEC20261231.txt")
    end

    it "422 sobre si les dates sont invalides (fin avant debut)" do
      get "/api/v1/exports/fec/apercu", params: { debut: "2026-12-31", fin: "2026-01-01" }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "422 sobre si une date est absente" do
      get "/api/v1/exports/fec/apercu", params: { debut: "2026-01-01" }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /api/v1/exports/fec" do
    let(:organisation) { create(:organisation) }
    let(:client) { create(:client, organisation: organisation) }
    let(:utilisateur) { create(:utilisateur, organisation: organisation, role: "owner") }

    before { authenticate_as(utilisateur, organisation) }

    it "télécharge le fichier FEC en pièce jointe, tenant-scopé" do
      facture = create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago)

      get "/api/v1/exports/fec", params: {
        debut: (facture.date_emission - 1).iso8601, fin: (facture.date_emission + 1).iso8601
      }

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Type"]).to include("text/plain")
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.headers["Content-Disposition"]).to include(
        "#{organisation.siret[0, 9]}FEC#{(facture.date_emission + 1).strftime('%Y%m%d')}.txt"
      )
      expect(response.body).to include(facture.numero)
    end

    it "porte l'étiquette d'honnêteté dans un en-tête dédié (percent-encodé)" do
      get "/api/v1/exports/fec", params: { debut: "2026-01-01", fin: "2026-12-31" }

      etiquette_decodee = Rack::Utils.unescape(response.headers["X-Fec-Etiquette"])
      expect(etiquette_decodee).to include("ce n'est pas une comptabilité tenue")
    end

    it "422 sobre si les dates sont invalides" do
      get "/api/v1/exports/fec", params: { debut: "pas-une-date", fin: "2026-12-31" }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
