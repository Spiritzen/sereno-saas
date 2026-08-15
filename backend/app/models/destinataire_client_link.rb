# frozen_string_literal: true

# Espace client — Étape A — SEULE table qui répond à « à qui appartient ce
# client, et qui a le droit de le voir » (cf. reco_espace_client_authentifie.txt
# E2/E3). Une ligne = une preuve posée UNE fois, jamais une correspondance
# automatique d'e-mail/SIRET (§1.4 execution_espace_client_etape_a.txt).
#
# `facture_id_preuve` trace la facture dont le lien de portail a servi de
# preuve — traçabilité RGPD/litige uniquement. L'AUTORISATION ne dépend que
# de l'EXISTENCE de la ligne (cf. CompteDestinataire#client_ids_revendiques),
# jamais d'une relecture de cette preuve après coup.
class DestinataireClientLink < ApplicationRecord
  # Une seule origine possible aujourd'hui (revendication par lien de
  # portail) — la suggestion par e-mail (fast-follow, hors périmètre) en
  # ajoutera une autre plus tard, jamais un octroi automatique.
  CREE_VIA = %w[lien_portail].freeze

  belongs_to :compte_destinataire
  belongs_to :client

  # Association EXPLICITE (pas juste une colonne UUID) : garantit que la
  # preuve pointe vers une VRAIE facture, et permet de vérifier ci-dessous
  # qu'elle appartient bien au client qu'elle est censée prouver.
  belongs_to :facture_preuve, class_name: "Facture", foreign_key: :facture_id_preuve, inverse_of: false

  validates :cree_via, presence: true, inclusion: { in: CREE_VIA }
  validates :compte_destinataire_id, uniqueness: { scope: :client_id }

  validate :facture_preuve_appartient_au_client

  private

  def facture_preuve_appartient_au_client
    return if facture_preuve.blank? || client.blank?

    if facture_preuve.client_id != client_id
      errors.add(:facture_preuve, "doit appartenir au même client que le lien qu'elle prouve")
    end
  end
end
