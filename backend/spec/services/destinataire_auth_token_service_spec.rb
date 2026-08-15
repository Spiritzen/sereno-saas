# frozen_string_literal: true

require "rails_helper"

RSpec.describe DestinataireAuthTokenService do
  describe "round-trip encode/decode" do
    it "encode puis décode retrouve le compte et la session" do
      compte = create(:compte_destinataire)
      resultat = DestinataireSession.generer!(compte_destinataire: compte)

      token = described_class.encode(compte_destinataire: compte, session: resultat.session)
      payload = described_class.decode(token)

      expect(payload[:compte_destinataire_id]).to eq(compte.id)
      expect(payload[:session_id]).to eq(resultat.session.id)
      expect(payload[:type]).to eq("destinataire")
    end
  end

  describe "validations à l'encodage" do
    it "lève si compte_destinataire est absent" do
      expect { described_class.encode(compte_destinataire: nil, session: build(:destinataire_session)) }
        .to raise_error(ArgumentError)
    end

    it "lève si la session ne correspond pas au compte" do
      compte = create(:compte_destinataire)
      autre_compte = create(:compte_destinataire)
      resultat = DestinataireSession.generer!(compte_destinataire: autre_compte)

      expect { described_class.encode(compte_destinataire: compte, session: resultat.session) }
        .to raise_error(ArgumentError)
    end
  end

  # ⚠️ DÉCISIF (§1.3 execution_espace_client_etape_a.txt) — confusion de
  # token, testée dans les DEUX sens, au niveau de la SIGNATURE JWT (pas
  # seulement une vérification de forme applicative).
  describe "CONFUSION DE TOKEN (décisif sécurité)" do
    it "un token APP (AuthTokenService) est rejeté par DestinataireAuthTokenService.decode" do
      organisation = create(:organisation)
      utilisateur = create(:utilisateur, organisation: organisation)
      session_app = Session.create!(
        utilisateur: utilisateur, organisation: organisation,
        refresh_token_hash: Digest::SHA256.hexdigest(SecureRandom.hex(64)),
        expire_at: 7.days.from_now
      )
      token_app = AuthTokenService.encode(utilisateur: utilisateur, organisation: organisation, session: session_app)

      expect { described_class.decode(token_app) }
        .to raise_error(DestinataireAuthTokenService::DecodeError)
    end

    it "un token DESTINATAIRE est rejeté par AuthTokenService.decode" do
      compte = create(:compte_destinataire)
      resultat = DestinataireSession.generer!(compte_destinataire: compte)
      token_destinataire = described_class.encode(compte_destinataire: compte, session: resultat.session)

      expect { AuthTokenService.decode(token_destinataire) }
        .to raise_error(AuthTokenService::DecodeError)
    end

    it "un token dont le payload porterait 'type: destinataire' mais signé avec la clé APP est rejeté (signature, pas juste la forme)" do
      payload = { type: "destinataire", compte_destinataire_id: SecureRandom.uuid, session_id: SecureRandom.uuid,
                  exp: 30.minutes.from_now.to_i }
      token_mal_signe = JWT.encode(payload, Rails.application.credentials.jwt_secret_key!, "HS256")

      expect { described_class.decode(token_mal_signe) }
        .to raise_error(DestinataireAuthTokenService::DecodeError)
    end
  end
end
