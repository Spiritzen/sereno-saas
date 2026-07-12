# frozen_string_literal: true

module Pa
  # Adapter sandbox : AUCUN appel réseau réel, AUCUNE persistance propre.
  # Déterministe : la même idempotency_key produit toujours le même
  # external_id (dérivation via Digest::UUID.uuid_v5, pas un tirage aléatoire)
  # — c'est ce qui rend le rejeu après crash sûr.
  #
  # Deux scénarios seulement : succès, erreur réseau. L'échec est piloté par
  # un paramètre injecté au constructeur (jamais une variable globale ou un
  # flag en base) : réservé aux tests, qui instancient
  # SandboxPaAdapter.new(simulate_network_error: true).
  class SandboxPaAdapter < BaseAdapter
    PROVIDER = "sandbox"
    PROVIDER_STATUS_ACCEPTED = "SANDBOX_ACCEPTED"
    NAMESPACE = "sereno:pa:sandbox"

    def initialize(simulate_network_error: false)
      @simulate_network_error = simulate_network_error
    end

    def submit(facture:, transmission:)
      raise Pa::NetworkError, "Erreur réseau simulée (sandbox)" if @simulate_network_error

      external_id = "SANDBOX-#{deterministic_uuid(transmission.idempotency_key)}"

      Pa::AdapterResult.new(
        provider: PROVIDER,
        external_id: external_id,
        provider_status: PROVIDER_STATUS_ACCEPTED,
        normalized_status: "depose",
        received_at: Time.current,
        raw_payload: {
          simulation: true,
          provider: PROVIDER,
          external_id: external_id,
          provider_status: PROVIDER_STATUS_ACCEPTED
        }
      )
    end

    private

    def deterministic_uuid(idempotency_key)
      Digest::UUID.uuid_v5(Digest::UUID::URL_NAMESPACE, "#{NAMESPACE}:#{idempotency_key}")
    end
  end
end
