class Utilisateur < ApplicationRecord
  belongs_to :organisation

  has_many :sessions, dependent: :destroy

  has_many :evenements_facture,
           class_name: "EvenementFacture",
           foreign_key: :utilisateur_id,
           dependent: :nullify

  # R2 (prompt_claude_code_inscription_owner_backend_r2.txt §5.A) — cohérent
  # avec CompteDestinataire#normaliser_email (même geste : strip + downcase
  # AVANT validation/stockage). Avant ce correctif, seul
  # Api::V1::AuthController#login normalisait, et uniquement au LOOKUP —
  # jamais à l'écriture (constat R0). La validation Rails ci-dessous
  # protège l'UX (message clair) ; l'index PostgreSQL fonctionnel sur
  # lower(trim(email)) (migration NormaliserUniciteEmailUtilisateurs)
  # reste la SEULE garantie contre une course concurrente — les deux sont
  # nécessaires, aucun ne remplace l'autre.
  before_validation :normaliser_email

  validates :email, presence: true, uniqueness: true,
                     format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :mot_de_passe_hash, presence: true
  validates :nom, presence: true
  validates :prenom, presence: true
  validates :role, presence: true
  validates :actif, inclusion: { in: [ true, false ] }

  validates :role, inclusion: {
    in: %w[super_admin owner comptable membre]
  }

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

  private

  # Normalise AVANT validation/stockage — miroir exact de
  # CompteDestinataire#normaliser_email.
  def normaliser_email
    self.email = email.to_s.strip.downcase if email.present?
  end
end
