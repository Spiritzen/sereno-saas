# frozen_string_literal: true

module Pa
  # Sélection d'adapter DATA-DRIVEN : basée sur plateforme_agreee.fournisseur,
  # jamais sur une variable d'environnement (moins honnête, moins traçable
  # qu'une donnée en base). Pas de registry élaboré : une simple résolution.
  class AdapterFactory
    class UnsupportedProviderError < StandardError; end

    def self.for(plateforme_agreee)
      case plateforme_agreee.fournisseur
      when "sandbox"
        Pa::SandboxPaAdapter.new
      else
        raise UnsupportedProviderError,
              "Fournisseur non supporté : #{plateforme_agreee.fournisseur.inspect}"
      end
    end
  end
end
