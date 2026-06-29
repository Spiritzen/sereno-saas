class TransmissionPa < ApplicationRecord
  self.table_name = "transmission_pa"

  DIRECTIONS = %w[sortant entrant].freeze
  STATUTS = %w[en_attente depose accepte rejete erreur].freeze
  FORMATS = %w[factur_x ubl cii].freeze

  belongs_to :organisation
  belongs_to :facture, optional: true
  belongs_to :avoir, optional: true

  belongs_to :plateforme_agreee,
             class_name: "PlateformeAgreee",
             foreign_key: :plateforme_agreee_id

  validates :direction, presence: true, inclusion: { in: DIRECTIONS }
  validates :statut, presence: true, inclusion: { in: STATUTS }
  validates :format, presence: true, inclusion: { in: FORMATS }

  validate :un_seul_document_cible
  validate :facture_appartient_a_la_meme_organisation
  validate :avoir_appartient_a_la_meme_organisation
  validate :plateforme_appartient_a_la_meme_organisation

  def sortant?
    direction == "sortant"
  end

  def entrant?
    direction == "entrant"
  end

  def document
    facture || avoir
  end

  private

  def un_seul_document_cible
    if facture.blank? && avoir.blank?
      errors.add(:base, "Une transmission PA doit concerner une facture ou un avoir")
    end

    if facture.present? && avoir.present?
      errors.add(:base, "Une transmission PA ne peut pas concerner une facture et un avoir en même temps")
    end
  end

  def facture_appartient_a_la_meme_organisation
    return if organisation.blank? || facture.blank?

    if facture.organisation_id != organisation_id
      errors.add(:facture, "doit appartenir à la même organisation que la transmission")
    end
  end

  def avoir_appartient_a_la_meme_organisation
    return if organisation.blank? || avoir.blank?

    if avoir.organisation_id != organisation_id
      errors.add(:avoir, "doit appartenir à la même organisation que la transmission")
    end
  end

  def plateforme_appartient_a_la_meme_organisation
    return if organisation.blank? || plateforme_agreee.blank?

    if plateforme_agreee.organisation_id != organisation_id
      errors.add(:plateforme_agreee, "doit appartenir à la même organisation que la transmission")
    end
  end
end
