# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Inscriptions", type: :request do
  def payload(organisation_overrides: {}, utilisateur_overrides: {})
    {
      inscription: {
        utilisateur: {
          prenom: "Sébastien",
          nom: "Cantrelle",
          email: "sebastien@example.test",
          mot_de_passe: "mot-de-passe-solide",
          confirmation_mot_de_passe: "mot-de-passe-solide"
        }.merge(utilisateur_overrides),
        organisation: {
          raison_sociale: "Studio Démo",
          siret: "12345678901234",
          regime_tva: "reel_normal",
          adresse_ligne1: "1 rue de la Paix",
          code_postal: "80000",
          ville: "Amiens",
          pays: "FR",
          email: "facturation@example.test"
        }.merge(organisation_overrides)
      }
    }
  end

  def set_cookie_header
    Array(response.headers["Set-Cookie"]).join("\n")
  end

  before { Rails.cache.clear }
  after { Rails.cache.clear }

  describe "POST /api/v1/inscription — succès" do
    it "crée exactement une Organisation et un OWNER, répond 201" do
      expect {
        post "/api/v1/inscription", params: payload(utilisateur_overrides: { email: "succes-1@example.test" })
      }.to change(Organisation, :count).by(1).and change(Utilisateur, :count).by(1)

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      expect(body["message"]).to eq("Inscription réussie")
      expect(body["utilisateur"]["email"]).to eq("succes-1@example.test")
      expect(body["utilisateur"]["role"]).to eq("owner")
      expect(body["organisation"]["raison_sociale"]).to eq("Studio Démo")
      expect(body["session_active"]).to eq(true)
    end

    it "stocke l'e-mail normalisé (espaces retirés, minuscule), même saisi autrement" do
      post "/api/v1/inscription", params: payload(
        utilisateur_overrides: { email: "  Succes-2@Example.TEST  " }
      )

      expect(response).to have_http_status(:created)

      utilisateur = Utilisateur.order(:created_at).last
      expect(utilisateur.email).to eq("succes-2@example.test")
    end

    it "hache le mot de passe (jamais en clair), et il reste utilisable via /login" do
      post "/api/v1/inscription", params: payload(utilisateur_overrides: { email: "login-ensuite@example.test" })
      expect(response).to have_http_status(:created)

      utilisateur = Utilisateur.find_by!(email: "login-ensuite@example.test")
      expect(utilisateur.mot_de_passe_hash).not_to eq("mot-de-passe-solide")
      expect(utilisateur.mot_de_passe_hash).not_to include("mot-de-passe-solide")

      post "/api/v1/auth/login", params: { email: "login-ensuite@example.test", password: "mot-de-passe-solide" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["message"]).to eq("Connexion réussie")
    end

    it "refuse le mauvais mot de passe au login ultérieur (message générique)" do
      post "/api/v1/inscription", params: payload(utilisateur_overrides: { email: "mauvais-mdp@example.test" })
      expect(response).to have_http_status(:created)

      post "/api/v1/auth/login", params: { email: "mauvais-mdp@example.test", password: "un-autre-mot-de-passe" }
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("Email ou mot de passe invalide")
    end
  end

  describe "POST /api/v1/inscription — stratégie de session A (immédiate)" do
    it "pose access_token et refresh_token en cookies HttpOnly, sans jamais exposer les tokens dans le JSON" do
      post "/api/v1/inscription", params: payload(utilisateur_overrides: { email: "session-immediate@example.test" })

      expect(response).to have_http_status(:created)
      expect(cookies[:access_token]).to be_present
      expect(cookies[:refresh_token]).to be_present
      expect(set_cookie_header.downcase).to include("httponly")

      body_brut = response.body
      expect(body_brut).not_to include(cookies[:access_token])
      expect(body_brut).not_to include(cookies[:refresh_token])
    end

    it "la session posée à l'inscription authentifie immédiatement une route protégée" do
      post "/api/v1/inscription", params: payload(utilisateur_overrides: { email: "session-active@example.test" })
      expect(response).to have_http_status(:created)

      get "/api/v1/auth/me"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["utilisateur"]["email"]).to eq("session-active@example.test")
    end
  end

  describe "POST /api/v1/inscription — contrat session_active (R2.1 §5)" do
    # Simule PROPREMENT l'échec attendu de création de Session (jamais un
    # thread/timing réel) : on fixe le refresh_token généré par
    # generer_refresh_token (SecureRandom.hex(64)) à une valeur déjà
    # utilisée par une Session existante — refresh_token_hash porte une
    # contrainte d'unicité Rails ET PostgreSQL (Session#validates), la
    # nouvelle Session échoue donc de façon déterministe et contrôlée.
    it "session_active: false si l'émission de session échoue après création du compte — compte et OWNER persistent, aucune organisation orpheline, aucun faux cookie" do
      refresh_token_fixe = "a" * 128
      utilisateur_existant = create(:utilisateur)
      Session.create!(
        utilisateur: utilisateur_existant,
        organisation: utilisateur_existant.organisation,
        refresh_token_hash: Digest::SHA256.hexdigest(refresh_token_fixe),
        expire_at: 7.days.from_now
      )

      allow(SecureRandom).to receive(:hex).with(64).and_return(refresh_token_fixe)

      expect {
        post "/api/v1/inscription", params: payload(utilisateur_overrides: { email: "session-ratee@example.test" })
      }.to change(Organisation, :count).by(1).and change(Utilisateur, :count).by(1)

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      expect(body["session_active"]).to eq(false)
      expect(body["utilisateur"]["email"]).to eq("session-ratee@example.test")

      expect(cookies[:access_token]).to be_blank
      expect(cookies[:refresh_token]).to be_blank
      expect(response.body).not_to match(/mot-de-passe-solide|BCrypt|\$2a\$|\$2b\$/)

      expect(Utilisateur.find_by!(email: "session-ratee@example.test")).to be_present
    end
  end

  describe "POST /api/v1/inscription — injection refusée" do
    it "IGNORE un rôle posté (super_admin) : le rôle final reste strictement owner" do
      post "/api/v1/inscription", params: payload(
        utilisateur_overrides: { email: "role-injecte@example.test", role: "super_admin" }
      )

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["utilisateur"]["role"]).to eq("owner")
      expect(Utilisateur.find_by!(email: "role-injecte@example.test").role).to eq("owner")
    end

    it "IGNORE un organisation_id posté : ne rattache jamais à une organisation existante" do
      autre_organisation = create(:organisation)

      post "/api/v1/inscription", params: payload(
        utilisateur_overrides: { email: "tenant-injecte@example.test", organisation_id: autre_organisation.id }
      )

      expect(response).to have_http_status(:created)
      utilisateur = Utilisateur.find_by!(email: "tenant-injecte@example.test")
      expect(utilisateur.organisation_id).not_to eq(autre_organisation.id)
    end

    it "IGNORE un id posté côté utilisateur ET organisation (jamais un id imposé par le client)" do
      id_fantaisiste = SecureRandom.uuid

      post "/api/v1/inscription", params: payload(
        utilisateur_overrides: { email: "id-injecte@example.test", id: id_fantaisiste },
        organisation_overrides: { id: id_fantaisiste }
      )

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["utilisateur"]["id"]).not_to eq(id_fantaisiste)
      expect(body["organisation"]["id"]).not_to eq(id_fantaisiste)
    end
  end

  describe "POST /api/v1/inscription — erreurs 422, rollback et absence de fuite" do
    it "confirmation différente -> 422, aucune écriture" do
      expect {
        post "/api/v1/inscription", params: payload(
          utilisateur_overrides: { email: "confirmation-ko@example.test", confirmation_mot_de_passe: "autre-chose" }
        )
      }.to change(Organisation, :count).by(0).and change(Utilisateur, :count).by(0)

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("Validation échouée")
      expect(body["details"].join).to match(/confirmation/i)
    end

    it "mot de passe trop court -> 422, aucune écriture" do
      expect {
        post "/api/v1/inscription", params: payload(
          utilisateur_overrides: { email: "mdp-court@example.test", mot_de_passe: "court", confirmation_mot_de_passe: "court" }
        )
      }.to change(Organisation, :count).by(0).and change(Utilisateur, :count).by(0)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "e-mail utilisateur manquant -> 422" do
      post "/api/v1/inscription", params: payload(utilisateur_overrides: { email: "" })

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "e-mail utilisateur invalide (format) -> 422" do
      post "/api/v1/inscription", params: payload(utilisateur_overrides: { email: "pas-un-email" })

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "champ Organisation obligatoire manquant (raison_sociale) -> 422, aucune écriture" do
      expect {
        post "/api/v1/inscription", params: payload(
          utilisateur_overrides: { email: "org-incomplete@example.test" },
          organisation_overrides: { raison_sociale: "" }
        )
      }.to change(Organisation, :count).by(0).and change(Utilisateur, :count).by(0)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "e-mail OWNER déjà présent sous une autre casse -> 422, aucune création" do
      create(:utilisateur, email: "existant@example.test")

      expect {
        post "/api/v1/inscription", params: payload(
          utilisateur_overrides: { email: "  Existant@Example.Test  " },
          organisation_overrides: { siret: "98765432109876" }
        )
      }.to change(Organisation, :count).by(0).and change(Utilisateur, :count).by(0)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "SIRET déjà utilisé -> 422, aucune création" do
      create(:organisation, siret: "55555555555555")

      expect {
        post "/api/v1/inscription", params: payload(
          utilisateur_overrides: { email: "siret-doublon@example.test" },
          organisation_overrides: { siret: "55555555555555" }
        )
      }.to change(Organisation, :count).by(0).and change(Utilisateur, :count).by(0)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "la réponse d'erreur ne contient aucun détail SQL, classe d'exception ou valeur sensible" do
      post "/api/v1/inscription", params: payload(
        utilisateur_overrides: { email: "sans-fuite@example.test", confirmation_mot_de_passe: "autre-chose" }
      )

      body_brut = response.body
      expect(body_brut).not_to match(/PG::|ActiveRecord::|SQLSTATE|StandardError/)
      expect(body_brut).not_to include("mot-de-passe-solide")
    end

    it "aucun digest, hash ou secret n'apparaît jamais dans une réponse réussie" do
      post "/api/v1/inscription", params: payload(utilisateur_overrides: { email: "aucun-secret@example.test" })

      body_brut = response.body
      expect(body_brut).not_to include("mot-de-passe-solide")
      expect(body_brut).not_to match(/mot_de_passe_hash|BCrypt|\$2a\$|\$2b\$/)
    end
  end

  describe "POST /api/v1/inscription — isolation multi-tenant" do
    it "deux inscriptions valides créent deux tenants réellement distincts, jamais mélangés" do
      post "/api/v1/inscription", params: payload(
        utilisateur_overrides: { email: "tenant-un@example.test" },
        organisation_overrides: { siret: "11122233344455" }
      )
      premier_id = JSON.parse(response.body)["organisation"]["id"]

      post "/api/v1/inscription", params: payload(
        utilisateur_overrides: { email: "tenant-deux@example.test" },
        organisation_overrides: { siret: "55544433322211" }
      )
      second_id = JSON.parse(response.body)["organisation"]["id"]

      expect(premier_id).not_to eq(second_id)

      owner_un = Utilisateur.find_by!(email: "tenant-un@example.test")
      owner_deux = Utilisateur.find_by!(email: "tenant-deux@example.test")

      expect(owner_un.organisation_id).to eq(premier_id)
      expect(owner_deux.organisation_id).to eq(second_id)
      expect(owner_un.organisation_id).not_to eq(owner_deux.organisation_id)
    end
  end

  describe "POST /api/v1/inscription — rate limiting (5/min, IP + e-mail OWNER normalisé)" do
    it "admet 5 tentatives, la 6e est throttlée avec Retry-After" do
      6.times do |i|
        post "/api/v1/inscription", params: payload(
          utilisateur_overrides: { email: "rate-limit@example.test", confirmation_mot_de_passe: "autre-chose" }
        ), env: { "REMOTE_ADDR" => "203.0.113.55" }

        if i < 5
          expect(response).to have_http_status(:unprocessable_entity)
        else
          expect(response).to have_http_status(:too_many_requests)
          expect(JSON.parse(response.body)["error"]).to eq("Trop de tentatives, réessayez dans quelques instants")
          expect(response.headers["Retry-After"]).to be_present
        end
      end
    end

    it "casse/espaces du même e-mail partagent le MÊME compteur (ne contournent pas le seuil)" do
      variantes_email = [
        "meme-personne@example.test",
        "  MEME-PERSONNE@EXAMPLE.TEST  ",
        "Meme-Personne@Example.Test",
        "meme-personne@example.test",
        "MEME-PERSONNE@example.test",
        "meme-personne@EXAMPLE.test"
      ]

      variantes_email.each_with_index do |email, i|
        post "/api/v1/inscription", params: payload(
          utilisateur_overrides: { email: email, confirmation_mot_de_passe: "autre-chose" }
        ), env: { "REMOTE_ADDR" => "203.0.113.56" }

        expect(response).to have_http_status(i < 5 ? :unprocessable_entity : :too_many_requests)
      end
    end

    it "isolation par IP : une IP fraîche n'est jamais affectée par la saturation d'une autre IP" do
      6.times do
        post "/api/v1/inscription", params: payload(
          utilisateur_overrides: { email: "ip-saturee@example.test", confirmation_mot_de_passe: "autre-chose" }
        ), env: { "REMOTE_ADDR" => "198.51.100.10" }
      end
      expect(response).to have_http_status(:too_many_requests)

      post "/api/v1/inscription", params: payload(
        utilisateur_overrides: { email: "ip-fraiche@example.test" }
      ), env: { "REMOTE_ADDR" => "198.51.100.11" }

      expect(response).to have_http_status(:created)
    end

    it "ne throttle jamais une autre route API, même api/v1/auth/login" do
      utilisateur = create(:utilisateur)

      6.times do
        post "/api/v1/inscription", params: payload(
          utilisateur_overrides: { email: "throttle-isole@example.test", confirmation_mot_de_passe: "autre-chose" }
        ), env: { "REMOTE_ADDR" => "203.0.113.57" }
      end
      expect(response).to have_http_status(:too_many_requests)

      post "/api/v1/auth/login",
           params: { email: utilisateur.email, password: "Sereno123!" },
           env: { "REMOTE_ADDR" => "203.0.113.57" }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/v1/inscription — rate limiting global anti-rotation (20/min par IP, R2.1 défaut bloquant B)" do
    it "vingt tentatives depuis la même IP avec vingt e-mails tous différents restent des réponses applicatives normales ; la 21e reçoit 429" do
      21.times do |i|
        post "/api/v1/inscription", params: payload(
          utilisateur_overrides: { email: "rotation-#{i}@example.test", confirmation_mot_de_passe: "autre-chose" }
        ), env: { "REMOTE_ADDR" => "203.0.113.90" }

        if i < 20
          # Chaque e-mail n'est utilisé qu'UNE fois : le compteur IP+e-mail
          # (5/min) ne peut jamais se déclencher ici — seule la limite
          # globale IP est en jeu.
          expect(response).to have_http_status(:unprocessable_entity)
        else
          expect(response).to have_http_status(:too_many_requests)
          expect(JSON.parse(response.body)["error"]).to eq("Trop de tentatives, réessayez dans quelques instants")
          expect(response.headers["Retry-After"]).to be_present
        end
      end
    end

    it "une IP B fraîche reste indépendante d'une IP A saturée par rotation" do
      20.times do |i|
        post "/api/v1/inscription", params: payload(
          utilisateur_overrides: { email: "rotation-a-#{i}@example.test", confirmation_mot_de_passe: "autre-chose" }
        ), env: { "REMOTE_ADDR" => "203.0.113.91" }
      end
      post "/api/v1/inscription", params: payload(
        utilisateur_overrides: { email: "rotation-a-saturante@example.test", confirmation_mot_de_passe: "autre-chose" }
      ), env: { "REMOTE_ADDR" => "203.0.113.91" }
      expect(response).to have_http_status(:too_many_requests) # IP A saturée par rotation

      post "/api/v1/inscription", params: payload(
        utilisateur_overrides: { email: "rotation-b@example.test" }
      ), env: { "REMOTE_ADDR" => "203.0.113.92" }
      expect(response).to have_http_status(:created)
    end

    it "les deux compteurs (IP+e-mail et IP-global) ne collisionnent pas : saturer l'un n'affecte pas l'autre sur une IP fraîche" do
      # Sature la limite GLOBALE d'une IP par rotation.
      21.times do |i|
        post "/api/v1/inscription", params: payload(
          utilisateur_overrides: { email: "collision-globale-#{i}@example.test", confirmation_mot_de_passe: "autre-chose" }
        ), env: { "REMOTE_ADDR" => "203.0.113.93" }
      end
      expect(response).to have_http_status(:too_many_requests)

      # Sur une IP fraîche, la limite IP+e-mail (5/min sur LE MÊME e-mail)
      # continue de fonctionner normalement, preuve que les deux compteurs
      # sont bien des clés de cache distinctes.
      6.times do |i|
        post "/api/v1/inscription", params: payload(
          utilisateur_overrides: { email: "collision-email-fixe@example.test", confirmation_mot_de_passe: "autre-chose" }
        ), env: { "REMOTE_ADDR" => "203.0.113.94" }

        expect(response).to have_http_status(i < 5 ? :unprocessable_entity : :too_many_requests)
      end
    end
  end

  describe "POST /api/v1/inscription — payloads structurellement mal formés (R2.1 §6)" do
    it "racine inscription absente -> réponse JSON sobre, sans page HTML ni backtrace" do
      post "/api/v1/inscription", params: { autre_chose: "1" }

      expect(response.content_type).to include("application/json")
      expect(response.body).not_to match(/<!DOCTYPE|<html|ActionController::ParameterMissing|param is missing/i)
      expect(JSON.parse(response.body)).to eq({ "error" => "Requête invalide" })
    end

    it "bloc utilisateur absent -> réponse JSON sobre, sans page HTML ni backtrace" do
      post "/api/v1/inscription", params: { inscription: { organisation: { raison_sociale: "Studio Démo" } } }

      expect(response.content_type).to include("application/json")
      expect(response.body).not_to match(/<!DOCTYPE|<html|ActionController::ParameterMissing|param is missing/i)
      expect(JSON.parse(response.body)).to eq({ "error" => "Requête invalide" })
    end

    it "bloc organisation absent -> réponse JSON sobre, sans page HTML ni backtrace" do
      post "/api/v1/inscription", params: { inscription: { utilisateur: { email: "x@example.test" } } }

      expect(response.content_type).to include("application/json")
      expect(response.body).not_to match(/<!DOCTYPE|<html|ActionController::ParameterMissing|param is missing/i)
      expect(JSON.parse(response.body)).to eq({ "error" => "Requête invalide" })
    end
  end
end
