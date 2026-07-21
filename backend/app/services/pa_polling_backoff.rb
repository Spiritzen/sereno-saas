# frozen_string_literal: true

# Tables de backoff du polling PA — EN CODE, jamais en base (même discipline
# que FactureStatusTransitionPolicy::TRANSITIONS).
#
# Fonction PURE : aucune écriture, aucune lecture DB. Reçoit un INDEX
# (poll_backoff_step ou consecutive_poll_errors), jamais une transmission.
class PaPollingBackoff
  # duplicate / stale / unmapped / requires_review : la facture n'a montré
  # aucun changement, on espace progressivement.
  NORMAL_STEPS = [
    1.minute, 5.minutes, 15.minutes, 30.minutes,
    1.hour, 3.hours, 6.hours, 12.hours, 24.hours
  ].freeze

  # Pa::NetworkError : la PA (ou le réseau) est en difficulté, on réessaie
  # plus vite au début, mais avec une table PLUS COURTE — au-delà, c'est la
  # PAUSE qui prend le relais (pas une boucle infinie de plus en plus lente).
  ERROR_STEPS = [ 1.minute, 5.minutes, 15.minutes, 1.hour, 6.hours ].freeze

  MAX_CONSECUTIVE_ERRORS_BEFORE_PAUSE = 5

  JITTER_RATIO = 0.10

  # ⚠️ Neutralisé par défaut en environnement de test — c'est ce qui rend les
  # specs déterministes (travel_to + assertions sur des valeurs exactes)
  # sans avoir à stuber le hasard dans chaque exemple. Peut être forcé
  # explicitement (jitter: true/false) si un test veut vérifier le jitter
  # lui-même.
  def self.default_jitter?
    !Rails.env.test?
  end

  def self.normal_delay(step_index, jitter: default_jitter?, random: Random)
    delay_for(NORMAL_STEPS, step_index, jitter: jitter, random: random)
  end

  def self.error_delay(attempt_index, jitter: default_jitter?, random: Random)
    delay_for(ERROR_STEPS, attempt_index, jitter: jitter, random: random)
  end

  def self.delay_for(table, index, jitter:, random:)
    base_seconds = table[[ index, table.size - 1 ].min].to_f

    return base_seconds.seconds unless jitter

    variation_seconds = base_seconds * JITTER_RATIO
    (base_seconds + random.rand(-variation_seconds..variation_seconds)).seconds
  end
  private_class_method :delay_for
end
