class Contact < ApplicationRecord
  belongs_to :organisation
  belongs_to :client

  validates :nom, presence: true
  validates :principal, inclusion: { in: [true, false] }
  validates :telephone, length: { maximum: 20 }, allow_blank: true

  validate :organisation_coherente_avec_client

  private

  def organisation_coherente_avec_client
    return if organisation.blank? || client.blank?

    if client.organisation_id != organisation_id
      errors.add(:organisation, "doit correspondre à l'organisation du client")
    end
  end
end