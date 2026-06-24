class Abonnement < ApplicationRecord
  belongs_to :organisation

  validates :plan, presence: true, inclusion: {
    in: %w[gratuit pro]
  }

  validates :statut, presence: true, inclusion: {
    in: %w[en_essai actif suspendu annule]
  }

  validates :date_debut, presence: true

  validates :prix_mensuel, numericality: {
    greater_than_or_equal_to: 0
  }, allow_nil: true
end