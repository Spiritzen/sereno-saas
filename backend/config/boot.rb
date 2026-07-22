ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

# Charge les variables d'environnement locales depuis .env en dev/test
# uniquement (jamais en production : Kamal injecte les secrets directement
# dans l'environnement du conteneur, cf. docs/dettes-connues.md n°1).
# `dotenv` est déjà vendu par le bundle (dépendance de kamal) : pas de gem
# supplémentaire nécessaire, on le requiert explicitement ici.
rails_env = ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"

if %w[development test].include?(rails_env)
  require "dotenv"

  env_root = File.expand_path("..", __dir__)
  Dotenv.load(
    File.join(env_root, ".env.#{rails_env}.local"),
    File.join(env_root, ".env.local"),
    File.join(env_root, ".env.#{rails_env}"),
    File.join(env_root, ".env")
  )
end

require "bootsnap/setup" # Speed up boot time by caching expensive operations.
