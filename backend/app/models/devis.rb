class Devis < ApplicationRecord
  self.table_name = "devis"


  belongs_to :organisation, inverse_of: :devis
  belongs_to :client, inverse_of: :devis

  has_many :lignes_devis,
           class_name: "LigneDevis",
           foreign_key: :devis_id,
           inverse_of: :devis,
           dependent: :destroy

  has_many :factures,
         class_name: "Facture",
         foreign_key: :devis_id,
         inverse_of: :devis,
         dependent: :restrict_with_exception

  has_many :acomptes,
         class_name: "Acompte",
         foreign_key: :devis_id,
         dependent: :restrict_with_exception

  validates :statut, presence: true, inclusion: {
    in: %w[brouillon envoye accepte refuse expire]
  }

  validates :total_ht, :total_tva, :total_ttc,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }

  validate :client_appartient_a_la_meme_organisation

  def recalculer_totaux!
    ht = lignes_devis.sum(:total_ht)
    tva = lignes_devis.sum("total_ht * taux_tva / 100")
    ttc = ht + tva

    update!(
      total_ht: ht,
      total_tva: tva,
      total_ttc: ttc
    )
  end

  private

  def client_appartient_a_la_meme_organisation
    return if organisation.blank? || client.blank?

    if client.organisation_id != organisation_id
      errors.add(:client, "doit appartenir à la même organisation que le devis")
    end
  end
end