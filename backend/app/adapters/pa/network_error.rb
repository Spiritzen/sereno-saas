# frozen_string_literal: true

module Pa
  # Erreur technique (réseau, timeout, réponse invalide) : la TransmissionPa
  # passe en erreur, la Facture n'est jamais touchée.
  class NetworkError < AdapterError; end
end
