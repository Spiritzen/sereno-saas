class EReporting < ApplicationRecord
  self.table_name = "e_reporting"
  self.inheritance_column = :_type_disabled

  TYPES = %w[transactions paiements].freeze
  STATUTS = %w[en_attente transmis accepte rejete].freeze

  belongs_to :organisation

  validates :type, presence: true, inclusion: { in: TYPES }
  validates :statut, presence: true, inclusion: { in: STATUTS }

  validates :periode_debut, presence: true
  validates :periode_fin, presence: true

  validates :nb_operations,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validates :montant_total,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }

  validate :periode_fin_apres_periode_debut
  validate :transmis_at_requis_si_transmis_ou_plus

  def en_attente?
    statut == "en_attente"
  end

  def transmis?
    statut == "transmis"
  end

  def accepte?
    statut == "accepte"
  end

  def rejete?
    statut == "rejete"
  end

  private

  def periode_fin_apres_periode_debut
    return if periode_debut.blank? || periode_fin.blank?

    if periode_fin < periode_debut
      errors.add(:periode_fin, "ne peut pas être avant la période de début")
    end
  end

  def transmis_at_requis_si_transmis_ou_plus
    return if statut == "en_attente"

    if transmis_at.blank?
      errors.add(:transmis_at, "est requis dès que le lot est transmis")
    end
  end
end