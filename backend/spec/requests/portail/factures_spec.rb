# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Portail::Factures", type: :request do
  let(:organisation) { create(:organisation) }
  let(:facture) { create(:facture, :emise, organisation: organisation, date_echeance: 1.day.ago) }

  describe "GET /portail/factures/:token" do
    it "renvoie la facture (données publiques) pour un token valide" do
      resultat = PortailFactureToken.generer!(facture: facture)

      get "/portail/factures/#{resultat.brut}"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["numero"]).to eq(facture.numero)
      expect(body["statut"]).to eq(facture.statut)
      expect(body["reste_a_payer"]).to be_present
      expect(body["client"]["raison_sociale"]).to eq(facture.client.raison_sociale)
      expect(body["lignes_facture"]).to be_an(Array)
      expect(body["pdf_disponible"]).to eq(true)
    end

    it "n'expose AUCUNE donnée interne (IDs, chemins de stockage, signaux CRM)" do
      resultat = PortailFactureToken.generer!(facture: facture)

      get "/portail/factures/#{resultat.brut}"

      body = JSON.parse(response.body)
      expect(body).not_to have_key("client_id")
      expect(body).not_to have_key("devis_id")
      expect(body).not_to have_key("pdf_url")
      expect(body).not_to have_key("xml_url")
      expect(body).not_to have_key("relancable")
      expect(body).not_to have_key("derniere_relance_at")
      expect(body).not_to have_key("relances_count")
      expect(body["client"]).not_to have_key("notes")
      expect(body["client"]).not_to have_key("email")
      expect(body["client"]).not_to have_key("identifiant_routage_pa")
    end

    it "réponse générique pour un token INCONNU (jamais généré)" do
      get "/portail/factures/#{SecureRandom.hex(64)}"

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq({ "error" => "Lien invalide ou expiré" })
    end

    it "la MÊME réponse générique pour un token EXPIRÉ — aucune fuite du cas réel" do
      resultat = PortailFactureToken.generer!(facture: facture)
      resultat.token.update_columns(expire_at: 1.minute.ago)

      get "/portail/factures/#{resultat.brut}"

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq({ "error" => "Lien invalide ou expiré" })
    end

    it "la MÊME réponse générique pour un token RÉVOQUÉ — aucune fuite du cas réel" do
      resultat = PortailFactureToken.generer!(facture: facture)
      resultat.token.revoquer!

      get "/portail/factures/#{resultat.brut}"

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq({ "error" => "Lien invalide ou expiré" })
    end

    it "ISOLATION : le token résout SA facture, jamais une autre (aucun paramètre id/facture_id n'existe dans la route)" do
      autre_facture = create(:facture, :emise, organisation: organisation, date_echeance: 1.day.ago)
      resultat = PortailFactureToken.generer!(facture: facture)

      get "/portail/factures/#{resultat.brut}"

      body = JSON.parse(response.body)
      expect(body["numero"]).to eq(facture.numero)
      expect(body["numero"]).not_to eq(autre_facture.numero)
    end
  end

  describe "GET /portail/factures/:token/pdf" do
    it "sert le PDF déjà archivé en lecture seule (jamais régénéré)" do
      resultat = PortailFactureToken.generer!(facture: facture)
      chemin = Rails.root.join(facture.pdf_url)
      FileUtils.mkdir_p(File.dirname(chemin))
      File.write(chemin, "%PDF-1.7 contenu factice de test")

      get "/portail/factures/#{resultat.brut}/pdf"

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Type"]).to eq("application/pdf")
    ensure
      File.delete(chemin) if chemin && File.exist?(chemin)
    end

    it "réponse générique pour un token invalide (même discipline que #show)" do
      get "/portail/factures/#{SecureRandom.hex(64)}/pdf"

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq({ "error" => "Lien invalide ou expiré" })
    end

    it "404 explicite (PDF indisponible) pour un token valide mais un fichier absent — pas une fuite de sécurité" do
      resultat = PortailFactureToken.generer!(facture: facture)

      get "/portail/factures/#{resultat.brut}/pdf"

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["error"]).to eq("PDF indisponible")
    end
  end

  describe "GET /portail/factures/:token/avoirs" do
    it "renvoie les avoirs ÉMIS liés à cette facture, jamais les brouillons" do
      resultat = PortailFactureToken.generer!(facture: facture)
      avoir_emis = create(:avoir, :emise, organisation: organisation, facture: facture, client: facture.client)
      create(:avoir, organisation: organisation, facture: facture, client: facture.client) # brouillon, exclu

      get "/portail/factures/#{resultat.brut}/avoirs"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.size).to eq(1)
      expect(body.first["numero"]).to eq(avoir_emis.numero)
      expect(body.first).not_to have_key("pdf_url")
    end

    it "ne renvoie AUCUN avoir d'une AUTRE facture" do
      resultat = PortailFactureToken.generer!(facture: facture)
      autre_facture = create(:facture, :emise, organisation: organisation, date_echeance: 1.day.ago)
      create(:avoir, :emise, organisation: organisation, facture: autre_facture, client: autre_facture.client)

      get "/portail/factures/#{resultat.brut}/avoirs"

      expect(JSON.parse(response.body)).to eq([])
    end

    it "réponse générique pour un token invalide" do
      get "/portail/factures/#{SecureRandom.hex(64)}/avoirs"

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq({ "error" => "Lien invalide ou expiré" })
    end
  end
end
