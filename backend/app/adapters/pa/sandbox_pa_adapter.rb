# frozen_string_literal: true

module Pa
  # Adapter sandbox : AUCUN appel réseau réel, AUCUNE persistance propre.
  # Déterministe : la même idempotency_key produit toujours le même
  # external_id (dérivation via Digest::UUID.uuid_v5, pas un tirage aléatoire)
  # — c'est ce qui rend le rejeu après crash sûr.
  #
  # #submit : deux scénarios, succès ou erreur réseau.
  # #fetch_status : la progression normale dérive un statut brut du NOMBRE
  # d'observations déjà enregistrées ; d'autres scénarios adverses
  # (doublon, désordre temporel, statut inconnu) sont sélectionnables pour
  # les tests. Tout est piloté par un paramètre injecté au CONSTRUCTEUR
  # (jamais une variable globale ou un flag en base) — même discipline que
  # l'échec réseau de B1+B2.
  class SandboxPaAdapter < BaseAdapter
    PROVIDER = "sandbox"
    PROVIDER_STATUS_ACCEPTED = "SANDBOX_ACCEPTED"
    NAMESPACE = "sereno:pa:sandbox"

    # Progression par défaut de #fetch_status, dérivée du NOMBRE
    # d'observations déjà enregistrées (observation_count) — jamais d'une
    # variable interne. Avantages (B3.1a §8) : déterministe · persistant
    # (recalculé depuis la base à chaque appel, survit à un redémarrage) ·
    # zéro table supplémentaire · feedback instantané au clic.
    # Au-delà de la dernière entrée, le statut reste stable (dernier élément
    # renvoyé indéfiniment).
    DEFAULT_STATUS_SEQUENCE = %w[
      SANDBOX_RECEIVED
      SANDBOX_AVAILABLE
      SANDBOX_APPROVED
    ].freeze

    FETCH_STATUS_SCENARIOS = %i[normal duplicate out_of_order unmapped].freeze

    def initialize(
      simulate_network_error: false,
      fetch_status_scenario: :normal,
      fetch_status_sequence: DEFAULT_STATUS_SEQUENCE
    )
      unless FETCH_STATUS_SCENARIOS.include?(fetch_status_scenario)
        raise ArgumentError, "Scénario fetch_status inconnu : #{fetch_status_scenario.inspect}"
      end

      @simulate_network_error = simulate_network_error
      @fetch_status_scenario = fetch_status_scenario
      @fetch_status_sequence = fetch_status_sequence
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

    def fetch_status(transmission:, observation_count:)
      raise Pa::NetworkError, "Erreur réseau simulée (sandbox)" if @simulate_network_error

      case @fetch_status_scenario
      when :duplicate
        # La PA renvoie deux fois LA MÊME notification : index figé à 0 quel
        # que soit observation_count -> même provider_event_id, même
        # occurred_at, même statut_brut à chaque appel.
        build_status_result(transmission, index: 0)
      when :out_of_order
        # Une notification NOUVELLE (provider_event_id distinct, dérivé
        # d'observation_count) mais dont l'occurred_at est celui de la TOUTE
        # PREMIÈRE observation : un message en retard. C'est le scénario qui
        # prouve la garde temporelle (P4) — voir spec dédiée.
        index = [ observation_count, @fetch_status_sequence.size - 1 ].min
        build_status_result(transmission, index: index, occurred_at_index: 0)
      when :unmapped
        build_status_result(transmission, index: observation_count, statut_brut_override: "SANDBOX_STATUS_INCONNU")
      else
        index = [ observation_count, @fetch_status_sequence.size - 1 ].min
        build_status_result(transmission, index: index)
      end
    end

    private

    def build_status_result(transmission, index:, occurred_at_index: index, statut_brut_override: nil)
      statut_brut = statut_brut_override || @fetch_status_sequence[index]

      Pa::StatusResult.new(
        provider: PROVIDER,
        provider_event_id: "SANDBOX-STATUS-#{deterministic_uuid("status:#{transmission.idempotency_key}:#{index}")}",
        statut_brut: statut_brut,
        occurred_at: deterministic_occurred_at(transmission, occurred_at_index),
        raw_payload: {
          simulation: true,
          provider: PROVIDER,
          statut_brut: statut_brut,
          observation_index: index
        }
      )
    end

    # Ancré sur transmis_at (fixe, déjà persisté) plutôt que sur Time.current :
    # entièrement déterministe pour un (transmission, index) donné, donc
    # strictement croissant avec l'index ET stable entre deux appels au même
    # index (nécessaire pour le scénario :duplicate).
    def deterministic_occurred_at(transmission, index)
      base = transmission.transmis_at || transmission.created_at

      base + (index + 1).minutes
    end

    def deterministic_uuid(seed)
      Digest::UUID.uuid_v5(Digest::UUID::URL_NAMESPACE, "#{NAMESPACE}:#{seed}")
    end
  end
end
