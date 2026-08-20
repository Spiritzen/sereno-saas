# frozen_string_literal: true

require "rails_helper"

# T0 (prompt_claude_code_fix_factory_factures_numero_unique.txt) — preuve
# permanente contre la régression CI observée : PG::UniqueViolation sur
# index_factures_unique_numero_by_org (organisation_id, numero), causée par
# un numero généré via rand(1000..9999) dans les traits :emise/:deposee de
# spec/factories/factures.rb. Ne teste pas une règle métier de l'application
# (le numero réel de production vient de Numerotation/NumerotationService,
# jamais de cette factory) — uniquement le contrat de la factory elle-même.
#
# Emplacement : PAS sous spec/factories/ malgré la préférence exprimée par
# le prompt (§9) — constat fait pendant l'exécution : factory_bot_rails
# (lib/factory_bot_rails/railtie.rb) `load` EAGERLY tout fichier .rb trouvé
# directement sous spec/factories/ au BOOT de l'application (tout
# environnement où la gem est chargée, pas seulement les runs RSpec), pour y
# découvrir les définitions de factories. Un fichier de spec y placé (donc
# avec `require "rails_helper"`) casse le boot de `rails db:test:prepare`,
# `rails console`, etc. avec `LoadError: cannot load such file --
# rails_helper` — confirmé en le plaçant d'abord à cet endroit puis en
# observant l'échec. spec/models/ est l'emplacement conventionnel le plus
# proche (spec/models/facture_spec.rb existe déjà pour Facture) et n'est
# chargé par aucun mécanisme hors RSpec.
RSpec.describe "Factory :facture — numérotation déterministe (T0)" do
  let(:organisation) { create(:organisation) }
  let(:client) { create(:client, organisation: organisation) }

  it "attribue un numero réellement DISTINCT à chaque facture :emise créée pour la MÊME organisation" do
    factures = Array.new(30) { create(:facture, :emise, organisation: organisation, client: client) }
    numeros = factures.map(&:numero)

    expect(numeros).to all(match(/\AFAC-\d{4}-\d{4,}\z/))
    expect(numeros.uniq.size).to eq(numeros.size)
    expect(factures).to all(be_valid)
  end

  it "attribue un numero réellement DISTINCT à chaque facture :deposee créée pour la MÊME organisation" do
    factures = Array.new(25) { create(:facture, :deposee, organisation: organisation, client: client) }
    numeros = factures.map(&:numero)

    expect(numeros.uniq.size).to eq(numeros.size)
  end

  it "ne fait jamais collision entre :emise et :deposee de la MÊME organisation (même index PostgreSQL)" do
    emises = Array.new(10) { create(:facture, :emise, organisation: organisation, client: client) }
    deposees = Array.new(10) { create(:facture, :deposee, organisation: organisation, client: client) }

    numeros = (emises + deposees).map(&:numero)

    expect(numeros.uniq.size).to eq(numeros.size)
  end
end
