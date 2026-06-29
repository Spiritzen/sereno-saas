class Acompte < ApplicationRecord
  STATUTS = %w[brouillon emis encaisse deduit].freeze

  CHAMPS_IMMUABLES_APRES_EMISSION = %w[
    organisation_id
    client_id
    devis_id
    numero
    pourcentage
    montant_ht
    montant_tva
    montant_ttc
    date_emission
  ].freeze

  belongs_to :organisation
  belongs_to :client
  belongs_to :facture, optional: true

  belongs_to :devis,
             class_name: "Devis",
             foreign_key: :devis_id,
             optional: true

  validates :statut, presence: true, inclusion: { in: STATUTS }

  validates :montant_ht, :montant_tva, :montant_ttc,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }

  validates :pourcentage,
            numericality: { greater_than: 0, less_than_or_equal_to: 100 },
            allow_nil: true

  validate :client_appartient_a_la_meme_organisation
  validate :facture_appartient_a_la_meme_organisation
  validate :facture_appartient_au_meme_client
  validate :devis_appartient_a_la_meme_organisation
  validate :devis_appartient_au_meme_client
  validate :numero_et_date_requis_si_emis
  validate :montants_coherents
  validate :empecher_modification_acompte_emis, on: :update

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
      errors.add(:client, "doit appartenir à la même organisation que l'acompte")
    end
  end

  def facture_appartient_a_la_meme_organisation
    return if organisation.blank? || facture.blank?

    if facture.organisation_id != organisation_id
      errors.add(:facture, "doit appartenir à la même organisation que l'acompte")
    end
  end

  def facture_appartient_au_meme_client
    return if client.blank? || facture.blank?

    if facture.client_id != client_id
      errors.add(:facture, "doit appartenir au même client que l'acompte")
    end
  end

  def devis_appartient_a_la_meme_organisation
    return if organisation.blank? || devis.blank?

    if devis.organisation_id != organisation_id
      errors.add(:devis, "doit appartenir à la même organisation que l'acompte")
    end
  end

  def devis_appartient_au_meme_client
    return if client.blank? || devis.blank?

    if devis.client_id != client_id
      errors.add(:devis, "doit appartenir au même client que l'acompte")
    end
  end

  def numero_et_date_requis_si_emis
    return if brouillon?

    errors.add(:numero, "est requis dès que l'acompte est émis") if numero.blank?
    errors.add(:date_emission, "est requise dès que l'acompte est émis") if date_emission.blank?
  end

  def montants_coherents
    return if montant_ht.blank? || montant_tva.blank? || montant_ttc.blank?

    if montant_ttc != montant_ht + montant_tva
      errors.add(:montant_ttc, "doit être égal à montant HT + montant TVA")
    end
  end

  def empecher_modification_acompte_emis
    return if statut_in_database == "brouillon"

    champs_bloques_modifies = changed & CHAMPS_IMMUABLES_APRES_EMISSION

    if champs_bloques_modifies.any?
      errors.add(:base, "Un acompte émis est immuable pour les champs de contenu")
    end
  end
end
