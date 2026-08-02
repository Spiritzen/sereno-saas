# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.plural /^(ox)$/i, "\\1en"
#   inflect.singular /^(ox)en/i, "\\1"
#   inflect.irregular "person", "people"
#   inflect.uncountable %w( fish sheep )
# end

# These inflection rules are supported but not enabled by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.acronym "RESTful"
# end

# "devis" est invariable en français (singulier = pluriel). Sans cette
# règle, l'inflecteur anglais le traite comme le pluriel régulier de "devi"
# (retrait du "s"), ce qui casse le nom du paramètre des routes nichées
# (:devi_id au lieu de :devis_id attendu par DevisController et consorts) et
# les noms de helpers de route.
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.uncountable "devis"
end
