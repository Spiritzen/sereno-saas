# frozen_string_literal: true

# R2 (prompt_claude_code_inscription_owner_backend_r2.txt §5) — corrige le
# même défaut déjà identifié par la reconnaissance R0 (rapport
# rapport_reconnaissance_entree_publique_auth_registration.txt §13) :
# `Api::V1::AuthController#login` normalise l'e-mail (`strip.downcase`)
# UNIQUEMENT au moment du LOOKUP, jamais à l'écriture, et
# `index_utilisateurs_on_email` est un index PostgreSQL STANDARD, sensible à
# la casse. Avant l'ouverture d'un parcours d'inscription public, l'unicité
# doit être garantie AU NIVEAU POSTGRESQL sur l'expression normalisée —
# jamais seulement par la validation Rails (qui protège l'UX, pas la
# concurrence).
#
# Étapes, dans cet ordre strict (§5.B du prompt) :
#   1. détecter, en SQL pur (jamais le modèle applicatif dans une migration),
#      d'éventuels doublons PRÉEXISTANTS après strip/downcase — si trouvés,
#      la migration s'arrête AVANT toute écriture, sans choisir arbitrairement
#      un compte à garder ni exposer les e-mails concernés (seul un COMPTE de
#      groupes conflictuels apparaît dans le message d'erreur) ;
#   2. normaliser les valeurs existantes UNIQUEMENT après ce contrôle ;
#   3. remplacer l'ancien index standard par un index FONCTIONNEL sur
#      lower(trim(email)), nommé explicitement.
#
# La colonne reste NOT NULL (jamais rendue nullable). `up`/`down` explicites
# (pas `change`) : la détection de doublons n'a de sens qu'à l'aller, `down`
# restaure uniquement le schéma (index), jamais la casse/l'espacement
# d'origine des e-mails déjà normalisés (comportement standard d'une
# migration de normalisation de données).
class NormaliserUniciteEmailUtilisateurs < ActiveRecord::Migration[8.1]
  ANCIEN_INDEX = "index_utilisateurs_on_email"
  NOUVEL_INDEX = "index_utilisateurs_on_email_normalise_unique"

  def up
    resultat = execute(<<~SQL.squish)
      SELECT COUNT(*) FROM (
        SELECT lower(trim(email)) AS email_normalise
        FROM utilisateurs
        GROUP BY lower(trim(email))
        HAVING COUNT(*) > 1
      ) AS groupes_conflictuels
    SQL

    nombre_groupes_conflictuels = resultat.getvalue(0, 0).to_i

    if nombre_groupes_conflictuels > 0
      raise ActiveRecord::IrreversibleMigration,
            "#{nombre_groupes_conflictuels} groupe(s) d'e-mails utilisateurs entrent en collision " \
            "après normalisation (espaces/casse) — migration arrêtée AVANT toute écriture. " \
            "Résoudre manuellement ces doublons (sans choix automatique de ce script) avant de relancer."
    end

    execute("UPDATE utilisateurs SET email = lower(trim(email))")

    remove_index :utilisateurs, name: ANCIEN_INDEX

    add_index :utilisateurs, "lower(trim(email))",
              unique: true,
              name: NOUVEL_INDEX
  end

  def down
    remove_index :utilisateurs, name: NOUVEL_INDEX

    add_index :utilisateurs, :email, unique: true, name: ANCIEN_INDEX
  end
end
