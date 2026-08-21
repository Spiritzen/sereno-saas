# frozen_string_literal: true

require "rails_helper"

# R2 (prompt_claude_code_inscription_owner_backend_r2.txt §9.A) — comble le
# vide identifié par la reconnaissance R0 : aucun spec modèle dédié
# n'existait pour Utilisateur (ses primitives n'étaient testées
# qu'indirectement via auth_security_spec.rb, au niveau requête).
RSpec.describe Utilisateur do
  describe "normalisation de l'e-mail avant validation" do
    it "retire les espaces et met en minuscule AVANT la validation" do
      utilisateur = build(:utilisateur, email: "  Sebastien@Example.TEST  ")

      utilisateur.valid?

      expect(utilisateur.email).to eq("sebastien@example.test")
    end
  end

  describe "unicité insensible à la casse (validation Rails)" do
    it "refuse un e-mail identique après normalisation, même saisi avec une casse différente" do
      create(:utilisateur, email: "double@example.test")
      doublon = build(:utilisateur, email: "Double@Example.Test")

      expect(doublon).not_to be_valid
      expect(doublon.errors[:email]).to be_present
    end

    it "refuse un e-mail identique après normalisation, même avec des espaces différents" do
      create(:utilisateur, email: "espaces@example.test")
      doublon = build(:utilisateur, email: "  espaces@example.test  ")

      expect(doublon).not_to be_valid
      expect(doublon.errors[:email]).to be_present
    end
  end

  describe "index PostgreSQL fonctionnel — la garantie qui compte, indépendante de Rails" do
    it "REFUSE en base deux utilisateurs dont l'e-mail ne diffère que par la casse/les espaces, MÊME en contournant la validation Rails" do
      organisation = create(:organisation)
      create(:utilisateur, organisation: organisation, email: "concurrence@example.test")

      doublon = build(:utilisateur, organisation: organisation, email: "  Concurrence@Example.Test  ")

      # save(validate: false) contourne délibérément la validation Rails —
      # seule la contrainte PostgreSQL doit encore protéger l'unicité ici.
      # C'est la preuve décisive : Rails peut avoir un bug demain, l'index
      # fonctionnel sur lower(trim(email)) reste la garantie ultime.
      expect {
        doublon.save!(validate: false)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "expose bien un index unique fonctionnel sur l'e-mail normalisé" do
      index = ActiveRecord::Base.connection.indexes(:utilisateurs).find do |idx|
        idx.unique && idx.columns.to_s.match?(/lower/i) && idx.columns.to_s.match?(/email/i)
      end

      expect(index).to be_present
    end
  end

  describe "mot de passe — primitives existantes" do
    it "définit un mot de passe haché (BCrypt), jamais stocké en clair" do
      utilisateur = build(:utilisateur, mot_de_passe_hash: nil)
      utilisateur.definir_mot_de_passe("Sereno123!")

      expect(utilisateur.mot_de_passe_hash).not_to eq("Sereno123!")
      expect(utilisateur.mot_de_passe_valide?("Sereno123!")).to be(true)
    end

    it "refuse un mot de passe erroné" do
      utilisateur = build(:utilisateur, mot_de_passe_hash: nil)
      utilisateur.definir_mot_de_passe("Sereno123!")

      expect(utilisateur.mot_de_passe_valide?("autre-chose")).to be(false)
    end

    it "lève une erreur si le mot de passe est trop court (< 8 caractères)" do
      utilisateur = build(:utilisateur, mot_de_passe_hash: nil)

      expect { utilisateur.definir_mot_de_passe("court") }.to raise_error(ArgumentError)
    end

    it "lève une erreur si le mot de passe est vide" do
      utilisateur = build(:utilisateur, mot_de_passe_hash: nil)

      expect { utilisateur.definir_mot_de_passe("") }.to raise_error(ArgumentError)
    end
  end

  describe "format de l'e-mail" do
    it "refuse un e-mail manifestement invalide" do
      utilisateur = build(:utilisateur, email: "pas-un-email")

      expect(utilisateur).not_to be_valid
      expect(utilisateur.errors[:email]).to be_present
    end
  end
end
