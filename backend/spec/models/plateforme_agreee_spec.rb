# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlateformeAgreee, type: :model do
  describe "chiffrement de credentials_chiffres (B5)" do
    it "1. CHIFFRÉ AU REPOS : la valeur brute en base n'est jamais le clair" do
      plateforme = create(:plateforme_agreee, credentials_chiffres: "secret-pa-de-test")

      brut = ActiveRecord::Base.connection.select_value(
        "SELECT credentials_chiffres FROM plateformes_agreees WHERE id = '#{plateforme.id}'"
      )

      expect(brut).not_to eq("secret-pa-de-test")
      expect(brut).not_to include("secret-pa-de-test")
      expect(brut).to be_present
    end

    it "2. ROUND-TRIP : la valeur relue via le modèle est déchiffrée correctement" do
      plateforme = create(:plateforme_agreee, credentials_chiffres: "secret-pa-de-test")

      relue = PlateformeAgreee.find(plateforme.id)

      expect(relue.credentials_chiffres).to eq("secret-pa-de-test")
    end

    it "3. NON DÉTERMINISTE : deux écritures de la même valeur donnent deux payloads différents en base" do
      premiere = create(:plateforme_agreee, credentials_chiffres: "meme-secret")
      seconde = create(:plateforme_agreee, credentials_chiffres: "meme-secret")

      brut_premiere = ActiveRecord::Base.connection.select_value(
        "SELECT credentials_chiffres FROM plateformes_agreees WHERE id = '#{premiere.id}'"
      )
      brut_seconde = ActiveRecord::Base.connection.select_value(
        "SELECT credentials_chiffres FROM plateformes_agreees WHERE id = '#{seconde.id}'"
      )

      expect(brut_premiere).not_to eq(brut_seconde)
    end

    it "4. PAS DE FUITE EN SÉRIALISATION : le blueprint de transmission n'expose jamais ce champ" do
      plateforme = create(:plateforme_agreee, credentials_chiffres: "secret-pa-de-test")
      transmission = create(:transmission_pa, :depose, plateforme_agreee: plateforme, organisation: plateforme.organisation)

      rendu = TransmissionPaBlueprint.render(transmission)

      expect(rendu).not_to include("secret-pa-de-test")
      expect(rendu).not_to include("credentials_chiffres")
    end

    it "accepte une valeur nil sans erreur (colonne optionnelle)" do
      plateforme = create(:plateforme_agreee, credentials_chiffres: nil)

      expect(plateforme.reload.credentials_chiffres).to be_nil
    end
  end
end
