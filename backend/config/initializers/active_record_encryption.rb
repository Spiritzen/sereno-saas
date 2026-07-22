# frozen_string_literal: true

# Clés AR::Encryption lues depuis l'ENVIRONNEMENT, jamais depuis
# config/credentials.yml.enc (décision actée B5 : alignement avec Kamal, qui
# injecte les secrets de prod directement en ENV — pas de master.key à
# transporter). En dev/test, ces variables sont fournies par .env (voir
# config/boot.rb et .env.example), jamais commitées.
Rails.application.config.active_record.encryption.primary_key =
  ENV.fetch("SERENO_AR_ENCRYPTION_PRIMARY_KEY", nil)

Rails.application.config.active_record.encryption.deterministic_key =
  ENV.fetch("SERENO_AR_ENCRYPTION_DETERMINISTIC_KEY", nil)

Rails.application.config.active_record.encryption.key_derivation_salt =
  ENV.fetch("SERENO_AR_ENCRYPTION_KEY_DERIVATION_SALT", nil)
