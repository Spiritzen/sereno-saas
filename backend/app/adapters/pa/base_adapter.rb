# frozen_string_literal: true

module Pa
  # Contrat minimal d'un adapter PA. N'écrit JAMAIS en base, ne connaît ni
  # ActiveRecord ni les transactions : il ne fait qu'appeler un provider (ou,
  # pour SandboxPaAdapter, le simuler) et retourner un Pa::AdapterResult.
  class BaseAdapter
    def submit(facture:, transmission:)
      raise NotImplementedError, "#{self.class} doit implémenter #submit"
    end

    # Interroge l'état côté PA d'une transmission déjà déposée. Comme #submit,
    # n'écrit ni ne lit la base : `observation_count` est reçu en PARAMÈTRE
    # (le nombre d'EvenementEntrantPa déjà enregistrés pour cette
    # transmission), jamais recalculé en interne. Retourne un Pa::StatusResult.
    def fetch_status(transmission:, observation_count:)
      raise NotImplementedError, "#{self.class} doit implémenter #fetch_status"
    end
  end
end
