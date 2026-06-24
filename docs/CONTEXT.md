# CONTEXT.md — Sereno

> Document de contexte destiné à **Claude Code**, aux assistants IA et à tout nouveau développeur rejoignant le projet.
> Il décrit la mission, le contexte réglementaire, les décisions d'architecture, le modèle de domaine, les règles métier inviolables et les pièges à éviter.
> Vitrine et démarrage rapide : voir **[README.md](./README.md)**.

---

## 1. En une phrase

**Sereno** est un SaaS multi-tenant qui permet aux indépendants et TPE françaises d'émettre des **factures électroniques conformes** (Factur-X), de les **transmettre via une Plateforme Agréée**, d'en **suivre le cycle de vie** et de les **archiver légalement** — en cachant 100 % de la complexité réglementaire derrière une UX rassurante.

**Promesse produit :** on ne vend pas un logiciel de facturation, on vend *« dors tranquille, tu es en règle »*.

---

## 2. Contexte réglementaire (à connaître absolument)

La réforme française de la facturation électronique impose, par étapes, l'e-facture à toutes les entreprises assujetties à la TVA.

### Calendrier
- **1er septembre 2026** : toutes les entreprises doivent pouvoir **recevoir** des factures électroniques ; les **grandes entreprises et ETI** doivent **émettre**.
- **1er septembre 2027** : les **PME, TPE, micro-entreprises et indépendants** doivent **émettre**.

→ **La cible principale de Sereno (les indépendants) a pour échéance d'émission septembre 2027.** C'est le moteur commercial : urgence datée, demande obligatoire.

### Principes
- **Plus d'envoi de PDF par e-mail** entre professionnels assujettis. La facture transite par une **Plateforme Agréée (PA)**.
- **Formats imposés** : **Factur-X** (PDF/A-3 avec XML CII embarqué), **UBL**, ou **CII**. Sereno privilégie **Factur-X** (lisible par l'humain + structuré pour la machine).
- **E-reporting** : pour les opérations hors périmètre e-facture (ventes B2C, international), les données de transaction et de paiement sont transmises à l'administration.
- **Sanctions** prévues en cas de non-conformité (amendes par facture non électronique, etc.).
- **Archivage** : les factures doivent être conservées **10 ans**.

### Positionnement (IMPORTANT — périmètre)
- Sereno **n'est PAS** une Plateforme Agréée. Devenir PA exige un agrément d'État lourd et capitalistique.
- Sereno est la **couche métier/UX au-dessus** d'une PA : il génère les factures conformes et se connecte à une PA via API pour la transmission réelle.
- Pour le **secteur public (B2G)**, la transmission passe par **Chorus Pro**.

> Cette distinction est structurante : tout le code de transmission passe par un **adapter** (`adapters/pa/`) qui isole Sereno des PA tierces. Ne jamais coder en dur un protocole de PA.

---

## 3. Utilisateurs cibles & proposition de valeur

| Cible | Douleur | Ce que Sereno apporte |
|-------|---------|------------------------|
| Indépendant / freelance | Peur de la réforme, zéro connaissance réglementaire | Conformité automatique, « 2 clics » |
| Micro-entrepreneur | Outils existants trop comptables / chers | Simplicité radicale + offre gratuite |
| TPE (< 10 salariés) | Pas de cabinet comptable dédié | Suivi du cycle de vie + relances auto |

**Différenciateurs vs Pennylane/Sellsy :** simplicité extrême, suivi temps réel du cycle de vie mis au premier plan, ton orienté « sérénité » et non « comptabilité ».

---

## 4. Décisions d'architecture (ADR condensés)

| Décision | Choix | Raison |
|----------|-------|--------|
| Framework backend | **Rails 8 (API)** | Rapidité CRUD, écosystème mûr, conventions fortes |
| Jobs / cache / cable | **Solid Queue / Solid Cache / Solid Cable** | Natifs Rails 8, **pas de Redis** → déploiement plus simple |
| Multi-tenant | **Row-level + `Current.organisation`** | Une seule base, isolation par scope, simple à raisonner |
| Auth | **JWT en cookies HttpOnly + BCrypt** | Cohérent avec l'expérience de l'auteur, sûr côté XSS |
| Autorisation | **Pundit** | Policies explicites, testables, par rôle |
| Génération PDF | **HexaPDF** | Pur Ruby, supporte **PDF/A-3** et pièces jointes (clé pour Factur-X) |
| XML CII | **Nokogiri** | Construction/validation XML robuste |
| Transmission PA | **Adapter pattern** | Découpler Sereno des PA tierces, swap facile |
| Sérialisation | **Blueprinter** | Rapide, lisible, sans surcouche lourde |
| Frontend data | **TanStack Query** | Cache serveur, invalidation, remplace les hooks maison |
| Validation form | **React Hook Form + Zod** | Produit form-centrique, validation typée partagée |
| Déploiement | **Kamal 2** | Déploiement Rails moderne, zero-downtime, rollback |

> Si l'écosystème Ruby Factur-X s'avère insuffisant pour la conformité PDF/A-3, **fallback prévu** : un micro-service Python (lib `factur-x`) appelé en interne. À n'envisager qu'en dernier recours.

---

## 5. Modèle de domaine détaillé

UUID partout. Tout est scopé par `organisation_id` (sauf `ORGANISATION` et tables plateforme).

### Domaine Auth & Tenant
- **ORGANISATION** — l'entreprise émettrice (= le client SaaS). Champs : raison sociale, SIRET, n° TVA intracommunautaire, régime TVA, adresse, mentions légales, identifiant sur la PA.
- **UTILISATEUR** — appartient à une organisation, porte un rôle.
- **SESSION** — refresh tokens (rotation, expiration 7 j).
- **ABONNEMENT** — plan SaaS (Gratuit / Pro), période, statut.

### Domaine CRM (destinataires)
- **CLIENT** — le **destinataire** d'une facture. Champs : type (`entreprise` / `particulier` / `public`), SIRET, n° TVA, adresse, **routage PA** (identifiant d'acheminement), statut. Un particulier (B2C) relève de l'e-reporting, pas de l'e-facture.
- **CONTACT** — personne rattachée à un client.

### Domaine Catalogue
- **PRODUIT** — prestation/produit réutilisable (désignation, PU HT, taux TVA par défaut).
- **TAUX_TVA** — taux + éventuelle mention d'exonération (ex. « TVA non applicable, art. 293 B du CGI » pour les franchisés).

### Domaine Facturation
- **DEVIS** / **LIGNE_DEVIS** — proposition commerciale, convertible en facture.
- **FACTURE** — document principal. États : `brouillon`, `emise`, `transmise`, `encaissee`, `archivee`, `annulee`. **Immuable dès l'émission.**
- **LIGNE_FACTURE** — désignation, quantité, PU HT, taux TVA, total HT.
- **ACOMPTE** — facture d'acompte (avant facturation finale).
- **AVOIR** — note de crédit / facture rectificative. **Seul moyen légal de corriger une facture émise.**

### Domaine Cycle de vie
- **EVENEMENT_FACTURE** — journal **append-only** des changements de statut (audit). Champs : facture_id, statut, source (interne / PA), payload, horodatage. **Jamais d'`UPDATE` ni de `DELETE`.**
- **NUMEROTATION** — registre séquentiel par organisation / année / type de document. Garantit une **suite continue sans trou**.

### Domaine Transmission
- **PLATEFORME_AGREEE** — configuration de la PA connectée à l'organisation (provider, credentials chiffrés).
- **TRANSMISSION_PA** — une tentative d'envoi : payload, statut, accusés de réception/dépôt, erreurs.
- **E_REPORTING** — lot de données de transaction/paiement transmis pour le B2C et l'international.

### Domaine Paiement
- **PAIEMENT** — encaissement rattaché à une facture (montant, méthode, date).
- **RELANCE** — relance automatique d'une facture impayée (niveau, date, canal).

---

## 6. Règles métier INVIOLABLES

Ces règles sont des invariants légaux. Toute violation est un bug critique.

1. **Immutabilité** — une `FACTURE` au statut ≠ `brouillon` ne peut **jamais** être modifiée ni supprimée. Toute correction passe par un `AVOIR` + nouvelle facture.
2. **Numérotation sans trou** — le numéro est attribué **au moment de l'émission**, de façon séquentielle et continue. **Interdiction absolue d'utiliser `count + 1`** (race conditions = doublons ou trous). Utiliser une **séquence PostgreSQL dédiée** ou un **advisory lock** par (organisation, année, type).
3. **Pas de numéro sur un brouillon** — un brouillon n'a pas de numéro définitif tant qu'il n'est pas émis.
4. **Archivage 10 ans** — à l'émission, le couple PDF/A-3 + XML est archivé, horodaté, et conservé 10 ans.
5. **Conformité pré-émission** — aucune facture ne peut être émise si `FactureComplianceCheck` échoue.
6. **Journal append-only** — `EVENEMENT_FACTURE` ne subit jamais d'`UPDATE`/`DELETE`.
7. **Isolation tenant** — toute requête métier est scopée par `Current.organisation`. Jamais de requête « globale » sur les données d'organisation.

---

## 7. Machine à états du cycle de vie

```
brouillon
   │ (émission : numéro attribué + Factur-X généré + archivage)
   ▼
emise
   │ (transmission via PA)
   ▼
deposee ──► recue ──► mise_a_disposition
                          │
            ┌─────────────┼──────────────┐
            ▼             ▼               ▼
        approuvee      refusee        en_litige
            │
            ▼
        encaissee (paiement reçu)
            │
            ▼
        archivee
```

- **14 statuts** possibles ; **4 obligatoires** au sens de la réforme : *Déposée*, *Refusée*, *Encaissement constaté*, *Paiement transmis*.
- Les statuts post-transmission **remontent de la PA** (webhook prioritaire, polling de secours via `PaStatusPollJob`).
- Chaque transition écrit un `EVENEMENT_FACTURE`.
- Implémentation : state machine explicite (ex. gem `aasm` ou machine maison) côté modèle `FACTURE`, transitions interdites en dur.

---

## 8. Moteur de conformité (`FactureComplianceCheck`)

Service object appelé avant émission. Renvoie une liste de contrôles `{ clé, ok, message }`, consommée telle quelle par le panneau vert du frontend.

Contrôles :
- `numero_sequentiel` — un numéro va être attribué dans la bonne séquence
- `mentions_obligatoires` — identité émetteur + destinataire, SIRET, n° TVA, date, échéance, mentions 2026
- `format_factur_x` — le PDF/A-3 + CII se génère et valide
- `destinataire_pa` — le destinataire est identifié/routable sur la PA (ou relève de l'e-reporting si B2C)
- `coherence_tva` — taux cohérents, totaux justes, exonérations correctement mentionnées
- `donnees_destinataire` — adresse, identifiants complets

Tant qu'un contrôle est `ok: false`, l'émission est bloquée (bouton désactivé côté UI).

---

## 9. Génération Factur-X (pipeline)

1. **Calcul** des totaux (HT, TVA par taux, TTC) côté `EmissionService`.
2. **PDF lisible** rendu via HexaPDF (gabarit facture).
3. **XML CII** construit via Nokogiri (`lib/factur_x/cii_builder.rb`), profil EN 16931.
4. **Embarquement** : le XML est attaché dans un **PDF/A-3** conforme (`lib/factur_x/pdf_a3_embedder.rb`).
5. **Archivage** du livrable + horodatage.
6. **Transmission** via `PaTransmissionService` → adapter de la PA.

---

## 10. Sécurité, RGPD, archivage

- JWT HttpOnly (access 15 min, refresh 7 j avec rotation), BCrypt.
- `Current.organisation` + `Current.utilisateur` posés par un `before_action` depuis le JWT.
- Concern `Tenantable` : `default_scope` ou scope explicite par `organisation_id`.
- Pundit : une policy par ressource, vérifiée sur chaque action.
- Credentials des PA **chiffrés** (Rails encrypted attributes).
- RGPD : isolation stricte, droit à l'effacement compatible avec l'obligation d'archivage légal (les factures restent archivées 10 ans même après suppression du compte — base légale : obligation comptable).
- Toutes les actions sensibles tracées.

---

## 11. Conventions de code

- **Langue du domaine : français** (`Facture`, `Client`, `Ligne`, `Avoir`…) pour coller au vocabulaire réglementaire ; **mécanique framework en anglais** (`Service`, `Job`, `Policy`, `Adapter`).
- **Pas de logique métier dans les contrôleurs** → tout en service objects.
- **Pas de logique métier dans les vues/serializers**.
- **Modèles fins**, services explicites, jobs idempotents.
- Tests : **RSpec** (models, services, requests) + **FactoryBot** ; viser une couverture forte sur les invariants légaux (immutabilité, numérotation, conformité).
- Frontend : composants typés, état serveur via TanStack Query (pas de `useEffect` de fetch maison), validation Zod partagée.
- Lint : **RuboCop** (back), **ESLint + Prettier** (front).
- Commits conventionnels, branches par feature, CI bloquante.

---

## 12. Environnement & déploiement

- Dev : `docker compose up` (Rails + PostgreSQL 16 + Vite + Solid Queue).
- CI : GitHub Actions — `rspec`, `vitest`, `rubocop`, build images.
- Prod : **Kamal 2** sur VPS (OVH/Hetzner), Traefik pour HTTPS (Let's Encrypt), PostgreSQL 16 managé ou conteneurisé avec sauvegardes chiffrées quotidiennes.
- Archivage légal : bucket objet dédié, rétention 10 ans, accès restreint.

---

## 13. Roadmap (rappel synthétique)

- **V1** — émission conforme (auth, clients, facture, Factur-X, numérotation, conformité, dashboard, écran 2 clics)
- **V1.1** — transmission PA + cycle de vie temps réel
- **V1.2** — relances auto + e-reporting + exports FEC
- **V1.3** — devis, avoirs, portail destinataire
- **V1.4** — Chorus Pro (B2G) + abonnements SaaS
- **V1.5** — production (Kamal, CI/CD, sauvegardes)

---

## 14. Glossaire réglementaire

| Terme | Définition |
|-------|------------|
| **PA** | Plateforme Agréée — plateforme certifiée par l'État qui achemine les e-factures |
| **PPF** | Portail Public de Facturation — annuaire/concentrateur de l'administration |
| **Factur-X** | Format hybride : PDF/A-3 lisible + XML CII embarqué |
| **CII** | Cross Industry Invoice — format XML structuré (norme EN 16931) |
| **UBL** | Universal Business Language — autre format XML autorisé |
| **E-reporting** | Transmission à l'administration des données B2C et internationales |
| **Chorus Pro** | Plateforme de facturation du secteur public (B2G) |
| **SIRET** | Identifiant d'établissement (14 chiffres) |
| **EN 16931** | Norme européenne de la facture électronique |
| **B2B / B2C / B2G** | Entre entreprises / vers particuliers / vers secteur public |
| **FEC** | Fichier des Écritures Comptables (export normé) |

---

## 15. Pièges à éviter (à lire avant de coder)

- ❌ **Ne jamais** modifier ou supprimer une facture émise → passer par un `AVOIR`.
- ❌ **Ne jamais** numéroter avec `count + 1` ou `max + 1` → séquence/advisory lock.
- ❌ **Ne jamais** coder en dur le protocole d'une PA → passer par l'adapter.
- ❌ **Ne jamais** envoyer une e-facture par simple e-mail → tout passe par la PA.
- ❌ **Ne jamais** faire de requête métier non scopée par l'organisation.
- ❌ **Ne pas** mettre de logique métier dans les contrôleurs.
- ❌ **Ne pas** émettre si `FactureComplianceCheck` échoue.
- ⚠️ Vérifier la **conformité PDF/A-3** réelle des livrables Factur-X (c'est le point technique le plus risqué ; tester tôt, fallback Python si besoin).
- ⚠️ Distinguer **B2B (e-facture)** de **B2C/international (e-reporting)** dès la saisie du client.

---

## 16. Références

- Service-public.fr — facturation électronique (calendrier officiel)
- impots.gouv.fr — « Je passe à la facturation électronique » + liste des PA agréées
- Norme EN 16931 (format Factur-X / CII)

> Les dates et obligations évoluent ; vérifier les sources officielles avant toute décision de conformité critique.
