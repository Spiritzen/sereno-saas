class PlateformeAgreee < ApplicationRecord
  self.table_name = "plateformes_agreees"
  self.inheritance_column = :_type_disabled

  TYPES = %w[pa chorus_pro].freeze
  STATUTS = %w[connecte deconnecte erreur].freeze

  belongs_to :organisation

  has_many :transmissions_pa,
         class_name: "TransmissionPa",
         foreign_key: :plateforme_agreee_id,
         dependent: :restrict_with_exception

  validates :fournisseur, presence: true, length: { maximum: 50 }
  validates :type, presence: true, inclusion: { in: TYPES }
  validates :api_url, presence: true
  validates :statut, presence: true, inclusion: { in: STATUTS }

  validates :organisation_id, uniqueness: {
    message: "a déjà une plateforme agréée configurée"
  }

  def connectee?
    statut == "connecte"
  end

  def deconnectee?
    statut == "deconnecte"
  end

  def en_erreur?
    statut == "erreur"
  end
end