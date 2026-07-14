# frozen_string_literal: true

module Pa
  # Résultat normalisé retourné par tout adapter PA pour #fetch_status.
  # Même discipline que Pa::AdapterResult (#submit) : un contrat explicite,
  # jamais un Hash nu.
  StatusResult = Struct.new(
    :provider,             # "sandbox", futur "chorus_pro"...
    :provider_event_id,    # identifiant d'événement fourni par le provider (nullable)
    :statut_brut,          # statut BRUT tel que renvoyé par le provider, opaque
    :occurred_at,          # horodatage FOURNISSEUR de la notification (nullable)
    :raw_payload,          # payload déjà filtré, jamais de secret/brut sensible
    keyword_init: true
  )
end
