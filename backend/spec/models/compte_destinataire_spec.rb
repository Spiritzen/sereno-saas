# frozen_string_literal: true

require "rails_helper"

RSpec.describe CompteDestinataire do
  describe "validations" do
    it "exige un e-mail" do
      compte = build(:compte_destinataire, email: nil)

      expect(compte).not_to be_valid
      expect(compte.errors[:email]).to be_present
    end

    it "exige un format d'e-mail valide" do
      compte = build(:compte_destinataire, email: "pas-un-email")

      expect(compte).not_to be_valid
      expect(compte.errors[:email]).to be_present
    end

    it "exige un e-mail unique (identifiant de connexion global)" do
      create(:compte_destinataire, email: "double@test.fr")
      doublon = build(:compte_destinataire, email: "double@test.fr")

      expect(doublon).not_to be_valid
      expect(doublon.errors[:email]).to be_present
    end

    it "normalise l'e-mail (espaces, casse) avant stockage — insensible à la casse" do
      create(:compte_destinataire, email: "Normalise@Test.FR")
      doublon = build(:compte_destinataire, email: "  normalise@test.fr  ")

      expect(doublon).not_to be_valid
      expect(doublon.errors[:email]).to be_present
    end

    it "exige un mot_de_passe_hash (posé via definir_mot_de_passe)" do
      compte = CompteDestinataire.new(email: "sans-mdp@test.fr")

      expect(compte).not_to be_valid
      expect(compte.errors[:mot_de_passe_hash]).to be_present
    end
  end

  describe "#definir_mot_de_passe / #mot_de_passe_valide?" do
    it "hache le mot de passe (bcrypt) — jamais stocké en clair" do
      compte = build(:compte_destinataire, mot_de_passe: "motdepasse123")

      expect(compte.mot_de_passe_hash).not_to eq("motdepasse123")
      expect(compte.mot_de_passe_valide?("motdepasse123")).to be(true)
    end

    it "refuse un mot de passe erroné" do
      compte = build(:compte_destinataire, mot_de_passe: "motdepasse123")

      expect(compte.mot_de_passe_valide?("autrechose")).to be(false)
    end

    it "lève une erreur si le mot de passe est trop court" do
      compte = CompteDestinataire.new(email: "court@test.fr")

      expect { compte.definir_mot_de_passe("court") }.to raise_error(ArgumentError)
    end
  end

  describe "#client_ids_revendiques" do
    it "ne renvoie QUE les client_id issus des liens — aucune autre source" do
      compte = create(:compte_destinataire)
      lien = create(:destinataire_client_link, compte_destinataire: compte)

      expect(compte.client_ids_revendiques).to eq([ lien.client_id ])
    end

    it "renvoie une liste vide sans aucun lien" do
      compte = create(:compte_destinataire)

      expect(compte.client_ids_revendiques).to eq([])
    end
  end

  describe "cascade à la suppression (RGPD)" do
    it "détruit ses liens et ses sessions" do
      compte = create(:compte_destinataire)
      create(:destinataire_client_link, compte_destinataire: compte)
      DestinataireSession.generer!(compte_destinataire: compte)

      expect {
        compte.destroy!
      }.to change(DestinataireClientLink, :count).by(-1)
        .and change(DestinataireSession, :count).by(-1)
    end
  end
end
