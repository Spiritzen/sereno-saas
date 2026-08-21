# frozen_string_literal: true

require "rails_helper"

RSpec.describe InscriptionOwnerService do
  def organisation_attributes(overrides = {})
    {
      raison_sociale: "Studio Démo",
      siret: "12345678901234",
      regime_tva: "reel_normal",
      adresse_ligne1: "1 rue de la Paix",
      code_postal: "80000",
      ville: "Amiens",
      pays: "FR",
      email: "facturation@example.test"
    }.merge(overrides)
  end

  def utilisateur_attributes(overrides = {})
    {
      prenom: "Sébastien",
      nom: "Cantrelle",
      email: "sebastien@example.test"
    }.merge(overrides)
  end

  def appeler(organisation_overrides: {}, utilisateur_overrides: {}, mot_de_passe: "mot-de-passe-solide", confirmation: "mot-de-passe-solide")
    described_class.call(
      organisation_attributes: organisation_attributes(organisation_overrides),
      utilisateur_attributes: utilisateur_attributes(utilisateur_overrides),
      mot_de_passe: mot_de_passe,
      confirmation_mot_de_passe: confirmation
    )
  end

  describe "création Organisation + OWNER" do
    it "crée exactement une Organisation et un Utilisateur" do
      expect { appeler }
        .to change(Organisation, :count).by(1)
        .and change(Utilisateur, :count).by(1)
    end

    it "associe l'utilisateur créé à l'organisation créée dans le MÊME appel" do
      resultat = appeler

      expect(resultat.utilisateur.organisation_id).to eq(resultat.organisation.id)
    end

    it "hache le mot de passe via la primitive existante, jamais en clair" do
      resultat = appeler(mot_de_passe: "un-mot-de-passe-correct", confirmation: "un-mot-de-passe-correct")

      expect(resultat.utilisateur.mot_de_passe_hash).not_to eq("un-mot-de-passe-correct")
      expect(resultat.utilisateur.mot_de_passe_valide?("un-mot-de-passe-correct")).to be(true)
    end
  end

  describe "rôle owner imposé" do
    it "attribue toujours le rôle owner, quel que soit ce qui est demandé" do
      resultat = appeler

      expect(resultat.utilisateur.role).to eq("owner")
    end

    it "IGNORE un rôle injecté dans utilisateur_attributes (défense en profondeur du service)" do
      resultat = appeler(utilisateur_overrides: { role: "super_admin" })

      expect(resultat.utilisateur.role).to eq("owner")
    end

    it "IGNORE un organisation_id injecté dans utilisateur_attributes : le rattachement suit TOUJOURS l'organisation créée dans ce même appel" do
      autre_organisation = create(:organisation)

      resultat = appeler(utilisateur_overrides: { organisation_id: autre_organisation.id })

      expect(resultat.utilisateur.organisation_id).to eq(resultat.organisation.id)
      expect(resultat.utilisateur.organisation_id).not_to eq(autre_organisation.id)
    end
  end

  describe "rollback total" do
    it "n'écrit ni Organisation ni Utilisateur si l'Organisation est invalide (SIRET déjà pris)" do
      create(:organisation, siret: "99999999999999")

      expect {
        expect {
          appeler(organisation_overrides: { siret: "99999999999999" })
        }.to raise_error(described_class::EchecInscription)
      }.to change(Organisation, :count).by(0).and change(Utilisateur, :count).by(0)
    end

    it "n'écrit ni Organisation ni Utilisateur si l'Utilisateur est invalide (e-mail déjà pris) — AUCUNE organisation orpheline" do
      create(:utilisateur, email: "deja-pris@example.test")

      expect {
        expect {
          appeler(utilisateur_overrides: { email: "deja-pris@example.test" })
        }.to raise_error(described_class::EchecInscription)
      }.to change(Organisation, :count).by(0).and change(Utilisateur, :count).by(0)
    end

    it "n'écrit rien si l'e-mail utilisateur est invalide (format)" do
      expect {
        expect {
          appeler(utilisateur_overrides: { email: "pas-un-email" })
        }.to raise_error(described_class::EchecInscription)
      }.to change(Organisation, :count).by(0).and change(Utilisateur, :count).by(0)
    end

    it "n'écrit rien si un champ Organisation obligatoire est manquant" do
      expect {
        expect {
          appeler(organisation_overrides: { raison_sociale: nil })
        }.to raise_error(described_class::EchecInscription)
      }.to change(Organisation, :count).by(0).and change(Utilisateur, :count).by(0)
    end

    it "n'écrit rien si la confirmation du mot de passe diffère" do
      expect {
        expect {
          appeler(confirmation: "autre-chose")
        }.to raise_error(described_class::EchecInscription, /confirmation/i)
      }.to change(Organisation, :count).by(0).and change(Utilisateur, :count).by(0)
    end

    it "n'écrit rien si le mot de passe est trop court" do
      expect {
        expect {
          appeler(mot_de_passe: "court", confirmation: "court")
        }.to raise_error(described_class::EchecInscription, /8 caractères/)
      }.to change(Organisation, :count).by(0).and change(Utilisateur, :count).by(0)
    end

    it "n'écrit rien si le mot de passe est absent" do
      expect {
        expect {
          appeler(mot_de_passe: nil, confirmation: nil)
        }.to raise_error(described_class::EchecInscription, /obligatoire/i)
      }.to change(Organisation, :count).by(0).and change(Utilisateur, :count).by(0)
    end
  end

  describe "course d'unicité PostgreSQL (RecordNotUnique, R2.1 défaut bloquant A)" do
    # Simule PROPREMENT le chemin où la validation Rails passe (aucun
    # doublon vu en lecture par les DEUX requêtes concurrentes) mais où
    # PostgreSQL, lui, refuse le second INSERT (course réellement gagnée
    # par l'autre requête entre la validation et l'écriture). Simulé par
    # stub sur #save! — jamais de thread réel ni de temporisation : la
    # preuve reste déterministe et non flaky.
    it "traduit ActiveRecord::RecordNotUnique en EchecInscription, sans fuite SQL, avec rollback total" do
      allow_any_instance_of(Utilisateur).to receive(:save!).and_raise(
        ActiveRecord::RecordNotUnique.new(
          "PG::UniqueViolation: ERROR: duplicate key value violates unique constraint " \
          "\"index_utilisateurs_on_email_normalise_unique\" DETAIL: Key (lower(btrim(email)))=(secret@example.test) already exists."
        )
      )

      organisation_avant = Organisation.count
      utilisateur_avant = Utilisateur.count

      expect { appeler }.to raise_error(described_class::EchecInscription) do |erreur|
        expect(erreur.messages).to eq([ "Cet e-mail ou ce SIRET est déjà utilisé." ])
        expect(erreur.messages.join).not_to match(/PG::|SQLSTATE|constraint|DETAIL|secret@example\.test/)
      end

      expect(Organisation.count).to eq(organisation_avant)
      expect(Utilisateur.count).to eq(utilisateur_avant)
    end
  end

  describe "isolation entre deux inscriptions successives" do
    it "crée deux tenants réellement distincts, chacun avec son propre OWNER" do
      premier = appeler(
        organisation_overrides: { siret: "11111111111111", email: "org-un@example.test" },
        utilisateur_overrides: { email: "owner-un@example.test" }
      )
      second = appeler(
        organisation_overrides: { siret: "22222222222222", email: "org-deux@example.test" },
        utilisateur_overrides: { email: "owner-deux@example.test" }
      )

      expect(premier.organisation.id).not_to eq(second.organisation.id)
      expect(premier.utilisateur.organisation_id).to eq(premier.organisation.id)
      expect(second.utilisateur.organisation_id).to eq(second.organisation.id)
      expect(premier.utilisateur.organisation_id).not_to eq(second.organisation.id)
    end
  end
end
