class TauxTva < ApplicationRecord
  belongs_to :organisation

  has_many :produits, dependent: :restrict_with_exception

  validates :libelle, presence: true, length: { maximum: 50 }
  validates :taux, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :par_defaut, inclusion: { in: [ true, false ] }
end
