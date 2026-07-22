# frozen_string_literal: true

module Pa
  # Rejet métier explicite par le provider (réservé aux vrais providers ;
  # le sandbox de V1.1-B1+B2 ne le déclenche jamais, voir SandboxPaAdapter).
  class RejectedError < AdapterError; end
end
