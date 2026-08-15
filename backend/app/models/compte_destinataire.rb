# frozen_string_literal: true

# Espace client — Étape A (15/08/2026) — compte DESTINATAIRE, AU-DESSUS des
# organisations : contrairement à `Utilisateur`, aucun `organisation_id`,
# jamais. `email` est l'identifiant de CONNEXION, unique globalement — SANS
# AUCUN rapport avec `client.email` (non unique, non validé, jamais comparé,
# cf. §1.5 execution_espace_client_etape_a.txt).
#
# Mot de passe : EXACT même technique que Utilisateur#definir_mot_de_passe /
# #mot_de_passe_valide? (BCrypt) — copiée, jamais réutilisée depuis le
# modèle app (§1.1 : pile d'auth totalement parallèle).
class CompteDestinataire < ApplicationRecord
  self.table_name = "comptes_destinataires"

  has_many :destinataire_client_links, dependent: :destroy
  has_many :clients, through: :destinataire_client_links
  has_many :destinataire_sessions, dependent: :destroy

  before_validation :normaliser_email

  validates :email, presence: true, uniqueness: true,
                     format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :mot_de_passe_hash, presence: true

  def definir_mot_de_passe(mot_de_passe)
    raise ArgumentError, "mot de passe obligatoire" if mot_de_passe.blank?
    raise ArgumentError, "mot de passe trop court" if mot_de_passe.length < 8

    self.mot_de_passe_hash = BCrypt::Password.create(mot_de_passe)
  end

  def mot_de_passe_valide?(mot_de_passe)
    return false if mot_de_passe.blank?
    return false if mot_de_passe_hash.blank?

    BCrypt::Password.new(mot_de_passe_hash).is_password?(mot_de_passe)
  rescue BCrypt::Errors::InvalidHash
    false
  end

  # SEULE source de « ce à quoi ce compte a droit » (§1.4) — dérivée
  # EXCLUSIVEMENT des liens posés par preuve. Jamais un email/organisation_id
  # fourni par ailleurs ; l'étape B s'appuiera dessus pour scoper les
  # factures visibles (Facture.where(client_id: client_ids_revendiques)).
  def client_ids_revendiques
    destinataire_client_links.pluck(:client_id)
  end

  private

  # Normalise AVANT validation/stockage : l'unicité Postgres par défaut est
  # sensible à la casse — normaliser ici la rend effectivement insensible à
  # la casse (même geste que Api::V1::AuthController#login sur son lookup).
  def normaliser_email
    self.email = email.to_s.strip.downcase if email.present?
  end
end
