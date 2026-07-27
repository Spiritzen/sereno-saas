# frozen_string_literal: true

# RÈGLE N°1 (B3.3) : un webhook ne s'applique JAMAIS à la mauvaise
# organisation. Ce service est le SEUL point de rattachement notification ->
# transmission -> organisation pour l'endpoint public Webhooks::PaController.
#
# Résolution NON AMBIGUË, appuyée sur l'invariant DB (index unique partiel,
# cf. migration AddUniqueIndexToTransmissionPaIdentifiantPa) : identifiant_pa
# identifie AU PLUS UNE transmission dans tout le système, tous providers et
# toutes organisations confondus. Il n'y a donc rien à désambiguïser au-delà
# de ce lookup.
#
# V1.2c : la transmission peut désormais cibler une facture OU un avoir
# (TransmissionPa#document, existant depuis l'origine). On refuse toujours
# une transmission sans AUCUN document cible (`document.blank?`), mais on ne
# présume plus qu'il s'agit forcément d'une facture.
#
# Fonction PURE côté métier : une seule lecture, aucune écriture, aucune
# notion de Current.organisation (l'appelant est un endpoint public, sans
# session). L'organisation et le document sont des RÉSULTATS de la
# résolution, jamais une entrée : impossible de les présumer avant d'avoir
# trouvé LA transmission.
class PaInboundNotificationResolver
  Resultat = Struct.new(
    :transmission,
    :plateforme_agreee,
    :document,
    :facture,
    :organisation,
    keyword_init: true
  )

  def self.call(identifiant_pa:)
    return nil if identifiant_pa.blank?

    transmission = TransmissionPa
      .where.not(identifiant_pa: nil)
      .find_by(identifiant_pa: identifiant_pa)

    return nil if transmission.blank?
    return nil if transmission.document.blank?

    Resultat.new(
      transmission: transmission,
      plateforme_agreee: transmission.plateforme_agreee,
      document: transmission.document,
      # Conservé pour compatibilité stricte avec l'existant (B3.3) : nil pour
      # une transmission d'avoir, la facture sinon — aucun appelant existant
      # ne doit changer de comportement.
      facture: transmission.facture,
      organisation: transmission.organisation
    )
  end
end
