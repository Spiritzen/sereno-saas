class Avoir < ApplicationRecord
  STATUTS = %w[
    brouillon
    emise
    deposee
    recue
    mise_a_disposition
    approuvee
    refusee
    en_litige
    encaissee
    archivee
    annulee
  ].freeze

  CHAMPS_IMMUABLES_APRES_EMISSION = %w[
    organisation_id
    facture_id
    client_id
    numero
    motif
    date_emission
    total_ht
    total_tva
    total_ttc
    pdf_url
    xml_url
    emis_at
  ].freeze

  belongs_to :organisation
  belongs_to :facture
  belongs_to :client

  has_many :lignes_avoir,
         class_name: "LigneAvoir",
         foreign_key: :avoir_id,
         inverse_of: :avoir,
         dependent: :destroy

  has_many :transmissions_pa,
         class_name: "TransmissionPa",
         foreign_key: :avoir_id,
         dependent: :restrict_with_exception

  validates :motif, presence: true
  validates :statut, presence: true, inclusion: { in: STATUTS }

  validates :total_ht, :total_tva, :total_ttc,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }

  validate :client_appartient_a_la_meme_organisation
  validate :facture_appartient_a_la_meme_organisation
  validate :facture_appartient_au_meme_client
  validate :facture_deja_emise
  validate :numero_et_date_requis_si_emis
  validate :empecher_modification_avoir_emis, on: :update
  
  def recalculer_totaux!
  ht = lignes_avoir.sum(:total_ht)
  tva = lignes_avoir.sum("total_ht * taux_tva / 100")
  ttc = ht + tva

  update!(
    total_ht: ht,
    total_tva: tva,
    total_ttc: ttc
  )
end

  def brouillon?
    statut == "brouillon"
  end

  def emis?
    statut != "brouillon"
  end

  private

  def client_appartient_a_la_meme_organisation
    return if organisation.blank? || client.blank?

    if client.organisation_id != organisation_id
      errors.add(:client, "doit appartenir à la même organisation que l'avoir")
    end
  end

  def facture_appartient_a_la_meme_organisation
    return if organisation.blank? || facture.blank?

    if facture.organisation_id != organisation_id
      errors.add(:facture, "doit appartenir à la même organisation que l'avoir")
    end
  end

  def facture_appartient_au_meme_client
    return if client.blank? || facture.blank?

    if facture.client_id != client_id
      errors.add(:facture, "doit appartenir au même client que l'avoir")
    end
  end

  def facture_deja_emise
    return if facture.blank?

    unless facture.emise?
      errors.add(:facture, "doit être émise pour pouvoir créer un avoir")
    end
  end

  def numero_et_date_requis_si_emis
    return if brouillon?

    errors.add(:numero, "est requis dès que l'avoir est émis") if numero.blank?
    errors.add(:date_emission, "est requise dès que l'avoir est émis") if date_emission.blank?
    errors.add(:emis_at, "est requis dès que l'avoir est émis") if emis_at.blank?
  end

  def empecher_modification_avoir_emis
    return if statut_in_database == "brouillon"

    champs_bloques_modifies = changed & CHAMPS_IMMUABLES_APRES_EMISSION

    if champs_bloques_modifies.any?
      errors.add(:base, "Un avoir émis est immuable pour les champs de contenu")
    end
  end
end