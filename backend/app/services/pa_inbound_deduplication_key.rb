# frozen_string_literal: true

# Construit la clé de déduplication d'une notification ENTRANTE de la PA.
#
# ⚠️ Distincte de l'idempotency_key de TransmissionPa (B1+B2), qui protège
# ce que Sereno ENVOIE. Celle-ci protège ce que Sereno REÇOIT — deux
# problèmes différents, deux clés différentes.
#
# PRIORITÉ 1 : provider + provider_event_id, quand le fournisseur en fournit
# un (le sandbox en fournit toujours un, déterministe — cf. SandboxPaAdapter).
# FALLBACK : SHA-256 d'une forme CANONIQUE et STABLE (clés triées
# récursivement, horodatage normalisé en ISO8601 UTC) — deux notifications
# identiques doivent produire le même hash quel que soit l'ordre de
# construction du payload d'origine.
class PaInboundDeduplicationKey
  def self.call(provider:, identifiant_pa:, statut_brut:, occurred_at:, payload:, provider_event_id: nil)
    return "#{provider}:event:#{provider_event_id}" if provider_event_id.present?

    Digest::SHA256.hexdigest(
      canonical_form(
        provider: provider,
        identifiant_pa: identifiant_pa,
        statut_brut: statut_brut,
        occurred_at: occurred_at,
        payload: payload
      )
    )
  end

  def self.canonical_form(provider:, identifiant_pa:, statut_brut:, occurred_at:, payload:)
    JSON.generate(
      provider: provider,
      identifiant_pa: identifiant_pa,
      statut_brut: statut_brut,
      occurred_at: occurred_at&.utc&.iso8601(6),
      payload: deep_sort(payload || {})
    )
  end
  private_class_method :canonical_form

  # Trie récursivement les clés d'un Hash (les Array conservent leur ordre :
  # un ordre de liste est une donnée métier, pas un artefact de sérialisation).
  def self.deep_sort(value)
    case value
    when Hash
      value.each_with_object({}) { |(k, v), acc| acc[k.to_s] = deep_sort(v) }.sort.to_h
    when Array
      value.map { |item| deep_sort(item) }
    else
      value
    end
  end
  private_class_method :deep_sort
end
