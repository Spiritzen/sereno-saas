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
end