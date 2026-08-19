# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Destinataire::Factures", type: :request do
  def authenticate_as(compte)
    session = DestinataireSession.generer!(compte_destinataire: compte).session
    allow_any_instance_of(Destinataire::BaseController)
      .to receive(:authenticate_destinataire!) do
        Current.compte_destinataire = compte
        Current.destinataire_session = session
      end
  end

  after { Current.reset }

  def lier!(compte, client, facture)
    DestinataireClientLink.create!(
      compte_destinataire: compte, client: client, cree_via: "lien_portail", facture_id_preuve: facture.id
    )
  end

  let(:organisation) { create(:organisation, raison_sociale: "Fournisseur Un") }
  let(:client) { create(:client, organisation: organisation, raison_sociale: "Mon Client") }
  let(:facture) { create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago) }
  let(:compte) { create(:compte_destinataire) }

  describe "ISOLATION (décisif)" do
    it "ne voit QUE les factures dont le client_id est dans ses liens" do
      lier!(compte, client, facture)
      authenticate_as(compte)

      get "/destinataire/factures"

      body = JSON.parse(response.body)
      numeros = body["groupes"].flat_map { |groupe| groupe["factures"].map { |f| f["numero"] } }
      expect(numeros).to eq([ facture.numero ])
    end

    it "une facture d'un client NON lié -> 404 générique en DÉTAIL" do
      autre_client = create(:client, organisation: organisation)
      autre_facture = create(:facture, :emise, organisation: organisation, client: autre_client, date_echeance: 1.day.ago)
      lier!(compte, client, facture)
      authenticate_as(compte)

      get "/destinataire/factures/#{autre_facture.id}"

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["error"]).to eq("Ressource introuvable")
    end

    it "une facture d'un client NON lié -> 404 générique en PDF" do
      autre_client = create(:client, organisation: organisation)
      autre_facture = create(:facture, :emise, organisation: organisation, client: autre_client, date_echeance: 1.day.ago)
      lier!(compte, client, facture)
      authenticate_as(compte)

      get "/destinataire/factures/#{autre_facture.id}/pdf"

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["error"]).to eq("Ressource introuvable")
    end

    it "un id INEXISTANT -> la MÊME réponse 404 générique (pas de distinction avec 'hors scope')" do
      lier!(compte, client, facture)
      authenticate_as(compte)

      get "/destinataire/factures/#{SecureRandom.uuid}"

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["error"]).to eq("Ressource introuvable")
    end

    it "deux destinataires distincts ne voient JAMAIS les factures l'un de l'autre" do
      autre_compte = create(:compte_destinataire)
      autre_client = create(:client, organisation: organisation)
      autre_facture = create(:facture, :emise, organisation: organisation, client: autre_client, date_echeance: 1.day.ago)
      lier!(compte, client, facture)
      lier!(autre_compte, autre_client, autre_facture)

      authenticate_as(compte)
      get "/destinataire/factures"
      numeros_compte = JSON.parse(response.body)["groupes"].flat_map { |g| g["factures"].map { |f| f["numero"] } }

      authenticate_as(autre_compte)
      get "/destinataire/factures"
      numeros_autre_compte = JSON.parse(response.body)["groupes"].flat_map { |g| g["factures"].map { |f| f["numero"] } }

      expect(numeros_compte).to eq([ facture.numero ])
      expect(numeros_autre_compte).to eq([ autre_facture.numero ])
    end

    it "lié à 2 fournisseurs : voit les 2 groupes, et RIEN d'un 3e fournisseur non lié" do
      organisation_b = create(:organisation, raison_sociale: "Fournisseur Deux")
      client_b = create(:client, organisation: organisation_b)
      facture_b = create(:facture, :emise, organisation: organisation_b, client: client_b, date_echeance: 1.day.ago)

      organisation_c = create(:organisation, raison_sociale: "Fournisseur Trois (non lié)")
      client_c = create(:client, organisation: organisation_c)
      create(:facture, :emise, organisation: organisation_c, client: client_c, date_echeance: 1.day.ago)

      lier!(compte, client, facture)
      lier!(compte, client_b, facture_b)
      authenticate_as(compte)

      get "/destinataire/factures"

      body = JSON.parse(response.body)
      noms_fournisseurs = body["groupes"].map { |g| g["fournisseur"]["raison_sociale"] }
      expect(noms_fournisseurs).to contain_exactly("Fournisseur Un", "Fournisseur Deux")
    end

    it "sans authentification -> 401 sur les 3 actions" do
      get "/destinataire/factures"
      expect(response).to have_http_status(:unauthorized)

      get "/destinataire/factures/#{facture.id}"
      expect(response).to have_http_status(:unauthorized)

      get "/destinataire/factures/#{facture.id}/pdf"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # Correctif du 16/08/2026 — fix_espace_client_exclut_brouillons.txt : un
  # brouillon (document interne, jamais émis) ne doit JAMAIS apparaître côté
  # destinataire, même pour un client revendiqué. Même règle que
  # FecExportService (`where.not(statut: "brouillon")`), posée sur le SCOPE
  # DE BASE — protège liste, détail ET PDF d'un coup.
  describe "exclusion des brouillons (correctif)" do
    it "LISTE : un client avec des brouillons ET des factures émises ne renvoie QUE les émises" do
      brouillon = create(:facture, organisation: organisation, client: client, date_echeance: 1.day.ago)
      lier!(compte, client, facture) # un seul lien couvre tout le client, brouillon compris
      authenticate_as(compte)

      get "/destinataire/factures"

      numeros = JSON.parse(response.body)["groupes"].flat_map { |g| g["factures"].map { |f| f["numero"] } }
      expect(numeros).to eq([ facture.numero ])
      expect(numeros).not_to include(brouillon.numero) # nil de toute façon (jamais émis)
    end

    it "DÉTAIL : l'id d'un brouillon d'un client revendiqué -> 404 générique" do
      brouillon = create(:facture, organisation: organisation, client: client, date_echeance: 1.day.ago)
      lier!(compte, client, facture)
      authenticate_as(compte)

      get "/destinataire/factures/#{brouillon.id}"

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["error"]).to eq("Ressource introuvable")
    end

    it "PDF : l'id d'un brouillon d'un client revendiqué -> 404 générique" do
      brouillon = create(:facture, organisation: organisation, client: client, date_echeance: 1.day.ago)
      lier!(compte, client, facture)
      authenticate_as(compte)

      get "/destinataire/factures/#{brouillon.id}/pdf"

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["error"]).to eq("Ressource introuvable")
    end

    it "non-régression : les factures émises restent visibles avec leur reste-à-payer/statut" do
      brouillon = create(:facture, organisation: organisation, client: client, date_echeance: 1.day.ago)
      lier!(compte, client, facture)
      authenticate_as(compte)

      get "/destinataire/factures"

      body = JSON.parse(response.body)
      facture_json = body["groupes"].first["factures"].first
      expect(facture_json["numero"]).to eq(facture.numero)
      expect(facture_json["statut_encaissement_local"]).to eq("non_payee")
      expect(facture_json).to have_key("reste_a_payer")
      expect(brouillon).to be_persisted # créé, juste absent de la réponse
    end
  end

  describe "GET /destinataire/factures — liste groupée" do
    it "groupe correctement par fournisseur (raison_sociale + logo_url minimal)" do
      lier!(compte, client, facture)
      authenticate_as(compte)

      get "/destinataire/factures"

      body = JSON.parse(response.body)["groupes"]
      expect(body.size).to eq(1)
      expect(body.first["fournisseur"]["raison_sociale"]).to eq("Fournisseur Un")
      expect(body.first["fournisseur"]).to have_key("logo_url")
      expect(body.first["factures"].first["numero"]).to eq(facture.numero)
    end

    it "recherche `q` filtre par numéro de facture" do
      autre_facture = create(:facture, :emise, organisation: organisation, client: client,
                              date_echeance: 1.day.ago, numero: "AUTRE-000")
      facture.update_columns(numero: "FAC-2026-1234")
      lier!(compte, client, facture) # un seul lien : couvre TOUTES les factures de ce client, dont autre_facture
      authenticate_as(compte)

      get "/destinataire/factures", params: { q: "1234" }

      numeros = JSON.parse(response.body)["groupes"].flat_map { |g| g["factures"].map { |f| f["numero"] } }
      expect(numeros).to eq([ "FAC-2026-1234" ])
    end

    it "recherche `q` filtre par raison sociale du FOURNISSEUR, insensible à la casse" do
      lier!(compte, client, facture)
      authenticate_as(compte)

      get "/destinataire/factures", params: { q: "fournisseur un" }

      numeros = JSON.parse(response.body)["groupes"].flat_map { |g| g["factures"].map { |f| f["numero"] } }
      expect(numeros).to eq([ facture.numero ])
    end

    it "recherche `q` qui ne correspond à rien -> liste vide" do
      lier!(compte, client, facture)
      authenticate_as(compte)

      get "/destinataire/factures", params: { q: "ne-correspond-a-rien-xyz" }

      body = JSON.parse(response.body)
      expect(body["groupes"]).to eq([])
      expect(body["pagination"]["total"]).to eq(0)
    end

    it "filtre statut=payee ne renvoie que les factures soldées (reste_a_payer == 0)" do
      facture_payee = create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago)
      create(:paiement, :confirme, organisation: organisation, facture: facture_payee, montant: facture_payee.total_ttc)
      lier!(compte, client, facture) # non payée — un seul lien couvre les 2 factures du client

      authenticate_as(compte)

      get "/destinataire/factures", params: { statut: "payee" }

      numeros = JSON.parse(response.body)["groupes"].flat_map { |g| g["factures"].map { |f| f["numero"] } }
      expect(numeros).to eq([ facture_payee.numero ])
    end

    it "filtre statut=en_attente ne renvoie que les factures avec un reste à payer" do
      facture_payee = create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago)
      create(:paiement, :confirme, organisation: organisation, facture: facture_payee, montant: facture_payee.total_ttc)
      lier!(compte, client, facture)

      authenticate_as(compte)

      get "/destinataire/factures", params: { statut: "en_attente" }

      numeros = JSON.parse(response.body)["groupes"].flat_map { |g| g["factures"].map { |f| f["numero"] } }
      expect(numeros).to eq([ facture.numero ])
    end

    it "un statut de filtre inconnu est ignoré (renvoie tout, comme si absent)" do
      lier!(compte, client, facture)
      authenticate_as(compte)

      get "/destinataire/factures", params: { statut: "valeur-inconnue" }

      numeros = JSON.parse(response.body)["groupes"].flat_map { |g| g["factures"].map { |f| f["numero"] } }
      expect(numeros).to eq([ facture.numero ])
    end

    it "tri whitelisté : un `tri` inconnu retombe sur le défaut (date_desc), jamais une erreur" do
      lier!(compte, client, facture)
      authenticate_as(compte)

      get "/destinataire/factures", params: { tri: "'; DROP TABLE factures; --" }

      expect(response).to have_http_status(:ok)
    end

    it "tri montant_desc trie par total_ttc décroissant" do
      petite = create(:facture, organisation: organisation, client: client, date_echeance: 1.day.ago)
      create(:ligne_facture, facture: petite, organisation: organisation, quantite: 1, prix_unitaire_ht: 10, taux_tva: 20)
      petite.reload.update_columns(statut: "emise", numero: "PETITE", date_emission: Date.current, emise_at: Time.current)

      grande = create(:facture, organisation: organisation, client: client, date_echeance: 1.day.ago)
      create(:ligne_facture, facture: grande, organisation: organisation, quantite: 1, prix_unitaire_ht: 1000, taux_tva: 20)
      grande.reload.update_columns(statut: "emise", numero: "GRANDE", date_emission: Date.current, emise_at: Time.current)

      lier!(compte, client, petite) # un seul lien couvre petite ET grande (même client)
      authenticate_as(compte)

      get "/destinataire/factures", params: { tri: "montant_desc" }

      numeros = JSON.parse(response.body)["groupes"].flat_map { |g| g["factures"].map { |f| f["numero"] } }
      expect(numeros).to eq([ "GRANDE", "PETITE" ])
    end

    it "filtre `fournisseur_id` : ne renvoie que les factures de ce fournisseur, reste borné au scope" do
      organisation_b = create(:organisation, raison_sociale: "Fournisseur Deux")
      client_b = create(:client, organisation: organisation_b)
      facture_b = create(:facture, :emise, organisation: organisation_b, client: client_b, date_echeance: 1.day.ago)

      lier!(compte, client, facture)
      lier!(compte, client_b, facture_b)
      authenticate_as(compte)

      get "/destinataire/factures", params: { fournisseur_id: organisation.id }

      body = JSON.parse(response.body)["groupes"]
      expect(body.size).to eq(1)
      expect(body.first["fournisseur"]["raison_sociale"]).to eq("Fournisseur Un")
    end

    it "filtre `fournisseur_id` HORS scope -> liste vide (jamais une fuite)" do
      autre_organisation = create(:organisation, raison_sociale: "Jamais revendiqué")
      lier!(compte, client, facture)
      authenticate_as(compte)

      get "/destinataire/factures", params: { fournisseur_id: autre_organisation.id }

      expect(JSON.parse(response.body)["groupes"]).to eq([])
    end
  end

  describe "GET /destinataire/factures — pagination (10/page)" do
    def creer_factures_emises!(nombre, prefixe:)
      Array.new(nombre) do |index|
        f = create(:facture, organisation: organisation, client: client, date_echeance: 1.day.ago)
        f.update_columns(
          statut: "emise",
          numero: format("%s-%02d", prefixe, index),
          date_emission: index.days.ago,
          emise_at: index.days.ago
        )
        f
      end
    end

    it "renvoie AU PLUS 10 factures par page, avec les métadonnées de pagination" do
      factures = creer_factures_emises!(15, prefixe: "FAC")
      lier!(compte, client, factures.first)
      authenticate_as(compte)

      get "/destinataire/factures"

      body = JSON.parse(response.body)
      numeros = body["groupes"].flat_map { |g| g["factures"].map { |f| f["numero"] } }
      expect(numeros.size).to eq(10)
      expect(body["pagination"]).to eq(
        "page" => 1, "par_page" => 10, "total" => 15, "total_pages" => 2
      )
    end

    it "page=2 renvoie la SUITE (les 5 restantes), jamais un doublon de la page 1" do
      factures = creer_factures_emises!(15, prefixe: "FAC")
      lier!(compte, client, factures.first)
      authenticate_as(compte)

      get "/destinataire/factures", params: { page: 1 }
      page1 = JSON.parse(response.body)["groupes"].flat_map { |g| g["factures"].map { |f| f["numero"] } }

      get "/destinataire/factures", params: { page: 2 }
      body2 = JSON.parse(response.body)
      page2 = body2["groupes"].flat_map { |g| g["factures"].map { |f| f["numero"] } }

      expect(page2.size).to eq(5)
      expect(page1 & page2).to eq([]) # aucune intersection
      expect(body2["pagination"]).to eq(
        "page" => 2, "par_page" => 10, "total" => 15, "total_pages" => 2
      )
    end

    it "une page au-delà du total -> liste vide, jamais une erreur" do
      factures = creer_factures_emises!(3, prefixe: "FAC")
      lier!(compte, client, factures.first)
      authenticate_as(compte)

      get "/destinataire/factures", params: { page: 99 }

      body = JSON.parse(response.body)
      expect(body["groupes"]).to eq([])
      expect(body["pagination"]["page"]).to eq(99)
      expect(body["pagination"]["total"]).to eq(3)
    end

    it "un `page` non numérique/négatif retombe sur la page 1, jamais une erreur" do
      factures = creer_factures_emises!(3, prefixe: "FAC")
      lier!(compte, client, factures.first)
      authenticate_as(compte)

      get "/destinataire/factures", params: { page: "'; DROP TABLE factures; --" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["pagination"]["page"]).to eq(1)
    end

    it "isolation TIENT avec la pagination : jamais une facture d'un client non revendiqué sur aucune page" do
      autre_client = create(:client, organisation: organisation)
      facture_hors_scope = create(:facture, :emise, organisation: organisation, client: autre_client,
                                   date_echeance: 1.day.ago, numero: "HORS-SCOPE")
      factures = creer_factures_emises!(12, prefixe: "FAC")
      lier!(compte, client, factures.first)
      authenticate_as(compte)

      get "/destinataire/factures", params: { page: 1 }
      page1 = JSON.parse(response.body)["groupes"].flat_map { |g| g["factures"].map { |f| f["numero"] } }
      get "/destinataire/factures", params: { page: 2 }
      page2 = JSON.parse(response.body)["groupes"].flat_map { |g| g["factures"].map { |f| f["numero"] } }

      expect(page1 + page2).not_to include("HORS-SCOPE")
      expect(facture_hors_scope).to be_persisted
    end

    it "recherche + statut + pagination cohabitent : pagine le résultat déjà FILTRÉ" do
      payees = Array.new(12) do |index|
        f = create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago,
                    numero: format("PAYEE-%02d", index))
        create(:paiement, :confirme, organisation: organisation, facture: f, montant: f.total_ttc)
        f
      end
      en_attente = create(:facture, :emise, organisation: organisation, client: client,
                           date_echeance: 1.day.ago, numero: "EN-ATTENTE")
      lier!(compte, client, payees.first)
      authenticate_as(compte)

      get "/destinataire/factures", params: { statut: "payee", page: 1 }

      body = JSON.parse(response.body)
      numeros = body["groupes"].flat_map { |g| g["factures"].map { |f| f["numero"] } }
      expect(numeros.size).to eq(10)
      expect(numeros).not_to include("EN-ATTENTE")
      expect(body["pagination"]["total"]).to eq(12) # total du résultat FILTRÉ (12 payées), pas 13
      expect(en_attente).to be_persisted
    end
  end

  describe "GET /destinataire/factures/:id — détail" do
    it "expose le détail public (facture + lignes + avoirs + fournisseur) et RIEN d'interne" do
      lier!(compte, client, facture)
      authenticate_as(compte)

      get "/destinataire/factures/#{facture.id}"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)

      expect(body["facture"]["numero"]).to eq(facture.numero)
      expect(body["facture"]).to have_key("reste_a_payer")
      expect(body["facture"]).to have_key("lignes_facture")
      expect(body["facture"]).not_to have_key("client_id")
      expect(body["facture"]).not_to have_key("pdf_url")
      expect(body["facture"]).not_to have_key("relancable")
      expect(body["facture"]).not_to have_key("derniere_relance_at")

      expect(body["fournisseur"]["raison_sociale"]).to eq("Fournisseur Un")
      expect(body["fournisseur"]).not_to have_key("email")
      expect(body["fournisseur"]).not_to have_key("iban")
      expect(body["fournisseur"]).not_to have_key("identifiant_pa")
      expect(body["fournisseur"]).not_to have_key("regime_tva")

      expect(body["avoirs"]).to eq([])
    end

    it "inclut les avoirs ÉMIS liés, jamais les brouillons" do
      avoir_emis = create(:avoir, :emise, organisation: organisation, client: client, facture: facture)
      create(:avoir, organisation: organisation, client: client, facture: facture) # brouillon
      lier!(compte, client, facture)
      authenticate_as(compte)

      get "/destinataire/factures/#{facture.id}"

      body = JSON.parse(response.body)
      expect(body["avoirs"].size).to eq(1)
      expect(body["avoirs"].first["numero"]).to eq(avoir_emis.numero)
    end
  end

  describe "GET /destinataire/factures/:id/pdf" do
    it "sert le PDF déjà archivé, en lecture seule (jamais régénéré)" do
      lier!(compte, client, facture)
      authenticate_as(compte)

      chemin = Rails.root.join(facture.pdf_url)
      FileUtils.mkdir_p(File.dirname(chemin))
      File.write(chemin, "%PDF-1.7 contenu factice de test")

      get "/destinataire/factures/#{facture.id}/pdf"

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Type"]).to include("application/pdf")
    ensure
      File.delete(chemin) if chemin && File.exist?(chemin)
    end

    it "404 explicite si le PDF n'existe pas encore (token valide, fichier absent)" do
      lier!(compte, client, facture)
      authenticate_as(compte)

      get "/destinataire/factures/#{facture.id}/pdf"

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["error"]).to eq("PDF indisponible")
    end
  end
end
