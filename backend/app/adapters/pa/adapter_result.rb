# frozen_string_literal: true

module Pa
  # Résultat normalisé retourné par tout adapter PA. Pas un Hash nu : un
  # contrat explicite, identique quel que soit le provider réel derrière.
  AdapterResult = Struct.new(
    :provider,           # "sandbox", futur "chorus_pro"...
    :external_id,        # identifiant externe fiable (SANDBOX-... en sandbox)
    :provider_status,     # statut brut renvoyé par le provider, opaque
    :normalized_status,   # statut TransmissionPa correspondant (ex. "depose")
    :received_at,         # horodatage de l'accusé
    :raw_payload,          # payload déjà filtré, jamais de secret/brut sensible
    keyword_init: true
  )
end
