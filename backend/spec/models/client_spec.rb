# frozen_string_literal: true

require "rails_helper"

RSpec.describe Client, type: :model do
  describe "validation du SIRET" do
    it "un client particulier est valide sans SIRET" do
      client = build(:client, type: "particulier", siret: nil)

      expect(client).to be_valid
    end

    it "un client particulier est invalide si le SIRET présent n'est pas numérique" do
      client = build(:client, type: "particulier", siret: "1234567890123A")

      expect(client).not_to be_valid
      expect(client.errors[:siret]).to include("doit être composé de 14 chiffres")
    end

    it "un client entreprise est invalide sans SIRET" do
      client = build(:client, type: "entreprise", siret: nil)

      expect(client).not_to be_valid
      expect(client.errors[:siret]).to include("est requis pour un client entreprise ou public")
    end

    it "un client entreprise est valide avec un SIRET de 14 chiffres" do
      client = build(:client, type: "entreprise", siret: "12345678901234")

      expect(client).to be_valid
    end

    it "un client entreprise est invalide avec un SIRET contenant des lettres" do
      client = build(:client, type: "entreprise", siret: "1234567890123A")

      expect(client).not_to be_valid
      expect(client.errors[:siret]).to include("doit être composé de 14 chiffres")
    end

    it "un client public est valide avec un SIRET de 14 chiffres" do
      client = build(:client, type: "public", siret: "12345678901234")

      expect(client).to be_valid
    end
  end
end
