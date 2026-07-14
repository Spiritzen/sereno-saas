# frozen_string_literal: true

# Traduit un statut BRUT du fournisseur en statut MÉTIER candidat.
#
# Fonction PURE : aucune écriture, aucune lecture DB. Un statut brut inconnu
# renvoie NIL — c'est au SERVICE appelant de classer le résultat en
# `unmapped` (ce n'est pas le rôle du mapper de décider quoi que ce soit).
class PaStatusMapper
  MAPPINGS = {
    "sandbox" => {
      "SANDBOX_RECEIVED"  => "recue",
      "SANDBOX_AVAILABLE" => "mise_a_disposition",
      "SANDBOX_APPROVED"  => "approuvee",
      "SANDBOX_PAID"      => "encaissee",
      "SANDBOX_REJECTED"  => "refusee",
      "SANDBOX_DISPUTED"  => "en_litige"
    }.freeze
  }.freeze

  def self.call(provider:, statut_brut:)
    MAPPINGS.fetch(provider, {})[statut_brut]
  end
end
