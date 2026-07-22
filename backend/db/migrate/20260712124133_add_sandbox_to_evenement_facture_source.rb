# frozen_string_literal: true

# Autorise la valeur "sandbox" sur evenement_facture.source, pour marquer
# honnêtement les événements produits par le simulateur de transmission PA
# (V1.1-B1+B2). Réversible explicitement (up/down) plutôt que `change` car
# une modification de CHECK constraint n'est pas auto-réversible par Rails.
#
# 0 ligne evenement_facture avec source != "interne" en local au moment de
# l'écriture de cette migration (confirmé par COUNT) : aucune donnée à migrer.
class AddSandboxToEvenementFactureSource < ActiveRecord::Migration[8.1]
  OLD_SOURCES = %w[interne pa webhook].freeze
  NEW_SOURCES = %w[interne pa webhook sandbox].freeze

  def up
    remove_check_constraint :evenement_facture, name: "check_evenement_facture_source"

    add_check_constraint :evenement_facture,
                          "source IN (#{sql_list(NEW_SOURCES)})",
                          name: "check_evenement_facture_source"
  end

  def down
    remove_check_constraint :evenement_facture, name: "check_evenement_facture_source"

    add_check_constraint :evenement_facture,
                          "source IN (#{sql_list(OLD_SOURCES)})",
                          name: "check_evenement_facture_source"
  end

  private

  def sql_list(values)
    values.map { |value| "'#{value}'" }.join(", ")
  end
end
