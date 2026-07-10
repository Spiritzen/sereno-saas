# frozen_string_literal: true

class Client < ApplicationRecord
  self.inheritance_column = :_type_disabled

  belongs_to :organisation

  has_many :contacts, dependent: :destroy

  has_many :devis,
           class_name: "Devis",
           foreign_key: :client_id,
           inverse_of: :client,
           dependent: :restrict_with_exception

  has_many :factures, dependent: :restrict_with_exception
  has_many :acomptes, dependent: :restrict_with_exception
  has_many :avoirs, dependent: :restrict_with_exception

  validates :type, presence: true, inclusion: {
    in: %w[entreprise particulier public]
  }

  validates :raison_sociale, presence: true
  validates :adresse_ligne1, presence: true
  validates :code_postal, presence: true
  validates :ville, presence: true
  validates :pays, presence: true, length: { is: 2 }

  validates :statut, presence: true, inclusion: {
    in: %w[actif archive]
  }

  validates :siret, length: { is: 14 },
                     format: { with: /\A\d{14}\z/, message: "doit être composé de 14 chiffres" },
                     allow_blank: true

  validate :siret_requis_pour_entreprise_ou_public

  def actif?
    statut == "actif"
  end

  def archive?
    statut == "archive"
  end

  private

  def siret_requis_pour_entreprise_ou_public
    return if type == "particulier"
    return if siret.present?

    errors.add(:siret, "est requis pour un client entreprise ou public")
  end
end
