class Utilisateur < ApplicationRecord
  belongs_to :organisation

  has_many :sessions, dependent: :destroy

  has_many :evenements_facture,
           class_name: "EvenementFacture",
           foreign_key: :utilisateur_id,
           dependent: :nullify

  validates :email, presence: true, uniqueness: true
  validates :mot_de_passe_hash, presence: true
  validates :nom, presence: true
  validates :prenom, presence: true
  validates :role, presence: true
  validates :actif, inclusion: { in: [true, false] }

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
end