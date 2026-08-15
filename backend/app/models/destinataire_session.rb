# frozen_string_literal: true

# Espace client — Étape A — miroir EXACT du patron `Session`/`refresh_token_hash`
# (SecureRandom + SHA256 + secure_compare + expire_at/revoque_at) — copié,
# jamais une réutilisation du modèle `Session` (§1.1 : pile parallèle).
class DestinataireSession < ApplicationRecord
  # « Se souvenir de moi » — plus généreux que la session app (7 jours,
  # utilisateurs métier) : un destinataire grand public revient rarement
  # aussi souvent qu'un utilisateur professionnel quotidien.
  DUREE_VALIDITE = 30.days

  belongs_to :compte_destinataire

  validates :token_hash, presence: true, uniqueness: true
  validates :expire_at, presence: true

  validate :empecher_modification_du_hash, on: :update

  class << self
    # Génère une session et renvoie le token BRUT — la SEULE fois où il
    # existe en clair (même discipline que PortailFactureToken.generer!).
    def generer!(compte_destinataire:)
      brut = SecureRandom.hex(64)

      session = compte_destinataire.destinataire_sessions.create!(
        token_hash: hasher(brut),
        expire_at: DUREE_VALIDITE.from_now
      )

      Resultat.new(session: session, brut: brut)
    end

    private

    def hasher(token_brut)
      Digest::SHA256.hexdigest(token_brut.to_s)
    end
  end

  Resultat = Struct.new(:session, :brut, keyword_init: true)

  def expire?
    expire_at <= Time.current
  end

  def revoque?
    revoque_at.present?
  end

  def actif?
    !expire? && !revoque?
  end

  # Immédiat : pas d'attente, pas de fenêtre de grâce (même discipline que
  # PortailFactureToken#revoquer!).
  def revoquer!
    update!(revoque_at: Time.current)
  end

  private

  # Append-only sur le HASH uniquement — `revoque_at` DOIT rester modifiable
  # (c'est le mécanisme de déconnexion).
  def empecher_modification_du_hash
    return unless token_hash_changed?

    errors.add(:token_hash, "ne peut jamais être modifié après création")
    throw(:abort)
  end
end
