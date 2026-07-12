# frozen_string_literal: true

module Pa
  # Contrat minimal d'un adapter PA. N'écrit JAMAIS en base, ne connaît ni
  # ActiveRecord ni les transactions : il ne fait qu'appeler un provider (ou,
  # pour SandboxPaAdapter, le simuler) et retourner un Pa::AdapterResult.
  class BaseAdapter
    def submit(facture:, transmission:)
      raise NotImplementedError, "#{self.class} doit implémenter #submit"
    end
  end
end
