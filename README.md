<div align="center">

# 🛡️ Sereno

### La facturation électronique conforme, sans prise de tête
**Émettre · Transmettre · Suivre · Archiver**

[![Portfolio](https://img.shields.io/badge/Portfolio-Sébastien_Cantrelle-7c3aed?style=for-the-badge)](https://spiritzen.github.io/portfolio/)
[![GitHub](https://img.shields.io/badge/GitHub-Spiritzen-181717?style=for-the-badge&logo=github)](https://github.com/Spiritzen)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-0077B5?style=for-the-badge&logo=linkedin)](https://www.linkedin.com/in/sebastien-cantrelle-26b695106/)

<br>

![Statut](https://img.shields.io/badge/MVP-conforme_validé-10b981?style=flat-square)
![Conformité](https://img.shields.io/badge/Factur--X-EN16931_+_France_CTC-7c3aed?style=flat-square)
![Avoirs](https://img.shields.io/badge/Avoirs-381_+_BT--25_conformes-10b981?style=flat-square)
![Rails](https://img.shields.io/badge/Rails-8_API-CC0000?style=flat-square&logo=rubyonrails)
![React](https://img.shields.io/badge/React-18_+_TS-61DAFB?style=flat-square&logo=react)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)

</div>

---

> **Sereno** est une plateforme SaaS **multi-tenant** de facturation électronique destinée aux **indépendants, micro-entrepreneurs et TPE françaises**.
> Elle génère des factures conformes au format **Factur-X**, les transmet via une **Plateforme Agréée (PA)**, suit leur **cycle de vie en temps réel** et les **archive légalement** — le tout en deux clics.
> **Sereno ne vend pas un logiciel de compta. Sereno vend la certitude d'être en règle.**
> **Chaque organisation est 100% isolée — conformité RGPD garantie par l'architecture.**

> 📎 Pour le détail métier, réglementaire et les décisions techniques approfondies, voir **[CONTEXT.md](./CONTEXT.md)**.

---

## 🎯 Pourquoi Sereno

La réforme française de la **facturation électronique** rend l'e-facture obligatoire pour toutes les entreprises assujetties à la TVA :

| Échéance | Obligation |
|----------|------------|
| **1er septembre 2026** | Réception électronique obligatoire pour **toutes** les entreprises + émission pour les grandes entreprises et ETI |
| **1er septembre 2027** | Émission électronique obligatoire pour les **PME, TPE, micro-entreprises et indépendants** |

Les gros acteurs (Pennylane, Sellsy…) visent les PME équipées d'un cabinet comptable. **Le créneau de Sereno : l'indépendant seul, qui veut être conforme sans rien comprendre à la réglementation.** On cache toute la complexité (formats CII/UBL, routage PA, mentions obligatoires) derrière une UX rassurante.

---

## ✅ Statut du projet — Juillet 2026

> Phase actuelle : **correction légale livrée (V1.2 avoirs complets)** — au-dessus de la couche transmission (V1.1), le cycle des **avoirs (notes de crédit)** est désormais opérationnel de bout en bout : émission conforme (Factur-X TypeCode **381** + référence **BT-25** à la facture corrigée), API, journal append-only, transmission via PA, gestion des lignes et frontend dédié. Dernier audit complet : **99/100** (28/07/2026, GREEN, socle intact). Depuis, **B4 est livré** : trois des quatre niveaux de conformité (XSD, Schematron EN 16931, PDF/A-3b) sont re-prouvés en CI à chaque commit, sur facture **et** avoir. Prochaine grande brique au choix : gestion des paiements (ou resserrement du polling).

Le moteur d'émission Factur-X (PDF/A-3 + XML CII) est **fonctionnel et prouvé conforme**, et son socle légal est **gelé** (\`tag v0.2.0-conformite-fr\`) : la frontière exacte du gel est documentée et versionnée dans [\`backend/SOCLE_GELE.md\`](./backend/SOCLE_GELE.md). Toute la couche transmission (transmission sandbox, ingestion des statuts, polling, webhook signé, rate limiting) et la brique des avoirs ont été construites **par-dessus** ce socle, sans jamais le modifier. Voir [Conformité prouvée](#-conformité-prouvée).

| Couche | Statut | Détail |
|--------|--------|--------|
| Étude réglementaire (réforme 2026/2027) | ✅ **Complet** | Calendrier, formats, PA, e-reporting, sanctions, archivage |
| Direction artistique + maquettes UX | ✅ **Complet** | Dashboard conformité + écran « facture en 2 clics » validés |
| Modèle de données (22 entités) | ✅ **Complet** | Schéma + invariants légaux (immutabilité, numérotation) |
| Architecture Rails 8 (API) | ✅ **Complet** | Arborescence, services, adapters, jobs définis |
| Backend — Auth JWT multi-tenant | ✅ **Complet** | Login / Refresh / Logout + \`id_organisation\` dans le token |
| Backend — CRUD Clients + Contacts | ✅ **Complet** | Destinataires, SIRET, TVA, routage PA |
| Backend — Création de facture + lignes | ✅ **Complet** | Brouillon → émise, totaux HT/TVA/TTC (TVA agrégée par taux) |
| Backend — Générateur Factur-X | ✅ **Complet** | PDF/A-3 + CII XML embarqué — **re-validé en CI à chaque commit** (veraPDF / XSD / Schematron), facture **et** avoir |
| Backend — Numérotation séquentielle | ✅ **Complet** | Sans trou, protégée par advisory lock (concurrence) |
| Backend — Moteur de conformité | ✅ **Complet** | Contrôle pré-émission bloquant |
| Backend — Mentions France CTC (Flux 2) | ✅ **Complet** | BT-30/34/49, notes PMT/PMD/AAB, ProfileID, BusinessProcessID — mentions implémentées ; **validation Mustang BR-FR manuelle au gel, non automatisée en CI** (aucun scénario France public, dette n°24) |
| Backend — Journal d'événements + API historique | ✅ **Complet** | Événements \`créée\` / \`émise\` append-only, API lecture scopée organisation, testée multi-tenant |
| Backend — Chiffrement des secrets PA | ✅ **Complet** | \`credentials_chiffres\` et secret webhook chiffrés (ActiveRecord::Encryption, clés en env) — chiffré au repos prouvé par test SQL brut |
| Backend — Transmission PA (sandbox) | ✅ **Complet** | Adapter + orchestration 3 phases (réseau hors transaction), idempotence sortante, honnêteté \`source=sandbox\` |
| Backend — Ingestion des statuts entrants | ✅ **Complet** | 5 résultats (applied/duplicate/stale/requires_review/unmapped), garde temporelle, déduplication, machine d'état en code |
| Backend — Polling automatique des statuts | ✅ **Complet** | Job récurrent, backoff + jitter, pause/stop distincts, base source de vérité (\`next_poll_at\`) |
| Backend — Webhook PA entrant sécurisé | ✅ **Complet** | Endpoint public, signature HMAC sur raw body (\`secure_compare\`), anti-rejeu temporel, rattachement scopé organisation, couloir d'ingestion unique partagé |
| Frontend — Auth + Landing | ✅ **Complet** | Inscription, landing premium |
| Frontend — Dashboard conformité | ✅ **Complet** | KPIs + greeting & échéance dynamiques |
| Frontend — Facture en 2 clics | ✅ **Complet** | Écran de création + panneau conformité |
| Frontend — Page détail facture (bandeau + timeline) | ✅ **Complet** | Bandeau premium + timeline cycle de vie + historique réel |
| Frontend — Supervision transmission | ✅ **Complet** | Dernière/prochaine synchro, erreurs, badge \`requires_review\` persistant (monte et redescend), bouton de relance d'un polling en pause |
| Frontend — Page Paramètres | ✅ **Complet** | Placeholder honnête (domaines à venir) |
| CI/CD — GitHub Actions (RSpec, RuboCop, bundler-audit + gate conformité) | ✅ **Complet** | Pipeline vert sur \`main\` (secrets de chiffrement injectés) |
| Rate limiting de l'endpoint webhook | ✅ **Complet** | \`rack-attack\` 60 req/min par IP + par organisation, Solid Cache |
| **Avoirs — émission conforme (381 + BT-25)** | ✅ **Complet** | Note de crédit Factur-X TypeCode 381, référence BT-25 à la facture, validée XSD + Schematron + PDF/A-3b **en CI** (comme la facture) |
| **Avoirs — API + journal** | ✅ **Complet** | CRUD, policy rôle+tenant, journal \`evenement_avoir\` append-only |
| **Avoirs — transmission PA** | ✅ **Complet** | Couloir d'ingestion rendu agnostique (facture ou avoir), sans duplication |
| **Avoirs — lignes + PDF filigrané** | ✅ **Complet** | Gestion des lignes, filigrane « AVOIR » sur le PDF (compatible PDF/A-3) |
| **Avoirs — frontend** | ✅ **Complet** | Création (montant à créditer par ligne), page détail, navigation croisée, DA ambre |
| **Solde facture après avoirs** | ✅ **Complet** | Synthèse « reste dû » dérivée (TTC légal jamais modifié) |
| Validateurs de conformité en CI (XSD + Schematron + PDF/A-3b) | ✅ **Complet** | Re-prouvés à chaque push, facture **et** avoir (standard + franchise) ; France CTC hors CI, aucun scénario public (dette n°24) |
| Relances automatiques | ⏳ **V1.2** | Jobs Solid Queue + e-mails |
| E-reporting (B2C / international) | ⏳ **V1.2** | Lots de transmission |
| Tests frontend (Vitest) | ⏳ **V1.2** | Harnais de test des composants (dette connue) |
| Devis → facture · Portail destinataire | ⏳ **V1.3** | Conversion, suivi côté client |
| Chorus Pro (B2G) · Abonnements SaaS | ⏳ **V1.4** | Adapter dédié · Plans Gratuit / Pro |
| Déploiement production (Kamal 2) | ⏳ **V1.5** | VPS OVH/Hetzner + HTTPS + CI/CD |

---

## 🏅 Conformité prouvée

> Chez Sereno, la conformité n'est pas *affirmée*, elle est **prouvée par les validateurs officiels** — les mêmes que ceux utilisés par les Plateformes Agréées. Un « PDF qui s'ouvre » ne suffit pas : chaque facture **et chaque avoir** franchit quatre niveaux de validation — dont **trois sont désormais rejoués en CI à chaque commit**.

| Niveau | Outil | Résultat |
|--------|-------|----------|
| **PDF/A-3b** (ISO 19005-3) | veraPDF 1.30.2 | ✅ **146/146** — re-prouvé en CI, facture **et** avoir |
| **Structure XML** (CII D22B) | XSD Factur-X 1.09 (via Mustang/KoSIT) | ✅ **VALID** — re-prouvé en CI |
| **Règles métier EN 16931** | Schematron FeRD (Mustang/KoSIT) | ✅ **0 failed-assert** — re-prouvé en CI, facture **et** avoir |
| **Profil France CTC / Flux 2** | Mustang (mentions implémentées) | ⚠️ **validé au gel — hors CI** (aucun scénario public, dette n°24) |

**Garanties vérifiées automatiquement :**
- **Round-trip** — le XML embarqué dans le PDF/A-3 est byte-identique au XML de référence (pas de pièce jointe vide ou divergente).
- **Cohérence PDF ↔ XML** — les totaux HT/TVA/TTC du PDF correspondent au centime au \`GrandTotalAmount\` du XML (règles BR-CO), calcul en \`BigDecimal\` avec arrondi \`ROUND_HALF_UP\`.
- **Assertion négative** — une facture non conforme (sans ligne, client archivé…) est **refusée** à l'émission : le pipeline sait aussi dire non.
- **Isolation multi-tenant testée** — l'API du journal d'événements est prouvée étanche : une organisation ne peut jamais lire les événements d'une autre (test d'isolation → 404, aucune donnée exposée).
- **Artefacts vendorés** — profil ICC sRGB et schémas officiels versionnés dans le dépôt, pour une image de production reproductible et indépendante de l'hôte.

> Le socle de conformité est **gelé** (\`tag v0.2.0-conformite-fr\`) : aucune modification du moteur légal sans re-validation par les quatre niveaux ci-dessus (les trois premiers étant désormais rejoués automatiquement en CI).

---

## 🛠 Stack technique

| Couche | Technologie | Version / détail |
|--------|-------------|------------------|
| **Backend** | Ruby on Rails | 8 — mode API |
| | Ruby | 3.3+ |
| | Authentification | JWT (HttpOnly Cookies) + BCrypt |
| | Autorisation | Pundit — policies par rôle |
| | Multi-tenant | \`ActiveSupport::CurrentAttributes\` — \`Current.organisation\` |
| | Background jobs | Solid Queue (natif Rails 8, sans Redis) |
| | Cache / Cable | Solid Cache + Solid Cable |
| | Génération PDF | HexaPDF — PDF/A-3 |
| | XML métier | Nokogiri — CII / Factur-X / UBL |
| | API docs | rswag — OpenAPI / Swagger |
| **Base de données** | PostgreSQL | 16 |
| **Frontend** | React | 18 |
| | TypeScript | Strict (\`.tsx\` partout) |
| | Vite | 6 |
| | Tailwind CSS | v4 (\`@tailwindcss/vite\`) |
| | TanStack Query | Cache & état serveur |
| | React Hook Form + Zod | Validation des formulaires |
| | Axios | Intercepteur refresh token |
| | React Router | v7 |
| | Recharts | Graphes dashboard |
| **Conformité** | Format e-facture | Factur-X (PDF/A-3 + CII), UBL, CII |
| | Validation | veraPDF · XSD Factur-X 1.09 · Schematron EN 16931 · Mustang |
| | Transmission | Plateforme Agréée (PA) via adapter |
| | Secteur public | Chorus Pro (B2G) |
| **Tests** | Backend | RSpec + FactoryBot + Faker (334+ examples) |
| | Frontend | ESLint + \`tsc\` (build) — _Vitest prévu (dette connue, non encore installé)_ |
| **DevOps** | Conteneurs | Docker (multi-stage, Debian slim) |
| | Déploiement | Kamal 2 |
| | CI/CD | GitHub Actions |
| | Reverse proxy | Traefik / Caddy (HTTPS auto) |
| | Hébergement | VPS OVH ou Hetzner |

---

## 🗄 Modèle de données

**22 entités** — UUID partout — **6 domaines** :

\`\`\`
Auth & Tenant   → ORGANISATION · UTILISATEUR · SESSION · ABONNEMENT
CRM             → CLIENT · CONTACT
Catalogue       → PRODUIT · TAUX_TVA
Facturation     → DEVIS · LIGNE_DEVIS · FACTURE · LIGNE_FACTURE · ACOMPTE
                  AVOIR · LIGNE_AVOIR
Cycle de vie    → EVENEMENT_FACTURE · EVENEMENT_AVOIR · NUMEROTATION
Transmission    → PLATEFORME_AGREEE · TRANSMISSION_PA · E_REPORTING
Paiement        → PAIEMENT · RELANCE
\`\`\`

### Entités clés

| Entité | Rôle | Invariant légal |
|--------|------|-----------------|
| \`ORGANISATION\` | L'entreprise émettrice (le client SaaS) | SIRET, régime TVA, mentions légales |
| \`CLIENT\` | Le **destinataire** de la facture | Routage PA, type (entreprise / particulier / public) |
| \`FACTURE\` | Document de facturation | **Immuable une fois émise** — corrigée uniquement par un AVOIR |
| \`LIGNE_FACTURE\` | Détail (désignation, qté, PU, TVA) | — |
| \`AVOIR\` | Note de crédit / rectification (TypeCode 381) | Seul moyen légal de corriger une facture émise · référence BT-25 obligatoire · somme des avoirs ≤ TTC facture |
| \`LIGNE_AVOIR\` | Détail crédité (repris de la facture) | Immuable une fois l'avoir émis |
| \`NUMEROTATION\` | Registre séquentiel par org / année / type | **Séquence continue, sans trou** (compteurs facture et avoir indépendants) |
| \`EVENEMENT_FACTURE\` | Journal append-only du cycle de vie facture | Trace d'audit des statuts officiels |
| \`EVENEMENT_AVOIR\` | Journal append-only du cycle de vie avoir | Table miroir, mêmes garanties d'inaltérabilité |
| \`PLATEFORME_AGREEE\` | Config de la PA connectée | — |
| \`TRANSMISSION_PA\` | Envoi via la PA + accusés | Statuts officiels de la réforme |

### Migrations Rails

| Version | Description |
|---------|-------------|
| V1 | Init — Auth, Tenant, Clients, Catalogue |
| V2 | Facturation — Devis, Factures, Lignes, Acomptes, Avoirs |
| V3 | Numérotation séquentielle + contrainte d'unicité par séquence |
| V4 | Cycle de vie — \`evenement_facture\` (append-only) |
| V5 | Transmission — PA, e-reporting, accusés |
| V6 | Paiements + relances |
| V7 | Abonnement SaaS + index de performance |

---

## 🔄 Cycle de vie de la facture

Le cœur du produit : un suivi **temps réel** des statuts officiels imposés par la réforme. La facture vit, et l'utilisateur la voit vivre.

\`\`\`
BROUILLON → ÉMISE → DÉPOSÉE (PA) → REÇUE → MISE À DISPOSITION
                                      ↓
                          APPROUVÉE  /  REFUSÉE  /  EN LITIGE
                                      ↓
                          ENCAISSÉE (paiement reçu)
                                      ↓
                          ARCHIVÉE (10 ans)
\`\`\`

- **14 statuts** possibles, dont **4 obligatoires** : *Déposée*, *Refusée*, *Encaissement constaté*, *Paiement transmis*.
- Chaque changement d'état génère un \`EVENEMENT_FACTURE\` (journal d'audit inaltérable).
- Les statuts remontent de la PA via webhook ou polling (job Solid Queue).

**Implémenté et exposé aujourd'hui :**
- Les statuts \`BROUILLON → ÉMISE\` sont opérationnels et testés (immutabilité garantie à l'émission).
- Chaque transition écrit un \`EVENEMENT_FACTURE\` **dans la même transaction** que la facture (aucun événement orphelin).
- Une **timeline** affiche la progression déduite du statut, et un **panneau Historique** liste les événements réellement enregistrés — deux sources distinctes, jamais fusionnées, sans donnée inventée.
- L'**API historique** (\`GET /api/v1/factures/:id/evenements\`) est en lecture seule, scopée à l'organisation et prouvée étanche entre tenants.
- La **transmission via PA (sandbox)** dépose la facture, reçoit un accusé et fait passer la facture à \`DÉPOSÉE\` ; les statuts remontés (reçue, mise à disposition, approuvée…) alimentent le journal.
- Les statuts entrants passent par **un couloir d'ingestion unique**, quelle que soit la porte : bouton manuel, **polling automatique** (backoff), ou **webhook temps réel signé**. Trois portes, une seule règle métier.
- Une **garde temporelle** rejette tout statut plus ancien que le dernier appliqué ; les contradictions sont classées \`requires_review\` et signalées par un **badge persistant** dans l'UI.
- La **correction d'une facture émise** passe par un **avoir** (note de crédit conforme, TypeCode 381) : il reprend tout ou partie des lignes de la facture, référence celle-ci (BT-25), suit son propre cycle de vie (journal \`evenement_avoir\`), se transmet via la même PA, et fait apparaître un **« reste dû »** sur la facture — sans jamais modifier son montant légal, qui reste immuable.

> Principe conservé : **Sereno conserve tout ce que la PA affirme, n'applique que ce que sa machine métier peut accepter sans mentir, et jamais un fait plus ancien que ce qu'il sait déjà.**

---

## 🔐 Sécurité, multi-tenant & conformité

- **JWT HttpOnly Cookies** — access token 15 min + refresh 7 j (rotation)
- **BCrypt** — zéro mot de passe en clair
- **\`Current.organisation\`** — \`id_organisation\` extrait du JWT, injecté dans chaque requête ; **tous les scopes filtrent par organisation** (isolation explicite, pas de \`default_scope\` global — choix assumé pour une isolation testable et lisible)
- **Pundit** — autorisation fine par rôle
- **RGPD** — aucune fuite de données entre organisations possible ; l'isolation est **testée** (accès cross-tenant → 404, aucune donnée exposée)
- **Immutabilité légale** — une facture émise ne peut **jamais** être modifiée ni supprimée ; toute correction passe par un \`AVOIR\` (note de crédit conforme, garde au niveau modèle via \`statut_in_database\`). Un avoir émis est lui aussi immuable.
- **Journal append-only** — les événements de facture **et d'avoir** ne sont ni modifiables ni supprimables ; l'API ne les expose qu'en lecture (acteur limité à \`id\` + \`display_name\`, jamais l'email ni les URLs de fichiers)
- **Numérotation sans trou** — advisory lock PostgreSQL + verrou de ligne sur un compteur dédié, dans la transaction d'émission (jamais de \`count + 1\`)
- **Secrets PA chiffrés au repos** — \`credentials_chiffres\` et le secret de signature webhook sont chiffrés via \`ActiveRecord::Encryption\` (clés en variables d'environnement, jamais versionnées) ; le chiffré au repos est **prouvé par un test lisant la colonne en SQL brut**
- **Webhook entrant sécurisé** — endpoint public sans JWT, mais protégé par **signature HMAC-SHA256 sur le corps brut** (comparaison à temps constant), **anti-rejeu temporel** (fenêtre) en plus de la déduplication, et **rattachement scopé organisation** prouvé étanche entre tenants
- **Archivage 10 ans** — chaque facture émise (PDF/A-3 + XML) est archivée et horodatée

### 4 rôles

| Rôle | Périmètre |
|------|-----------|
| \`SUPER_ADMIN\` | Administration de la plateforme Sereno |
| \`OWNER\` | Propriétaire de l'organisation — tout : facturation, équipe, abonnement |
| \`COMPTABLE\` | Lecture finance + exports comptables (FEC) |
| \`MEMBRE\` | Création de devis et factures |

> Un **portail destinataire** (V1.3) permet au CLIENT de consulter et suivre ses factures reçues.

---

## 🏗 Architecture Backend (Rails 8 — API)

\`\`\`
backend/
├── SOCLE_GELE.md              ⭐ Frontière du socle légal gelé (versionnée)
│
├── app/
│   ├── controllers/api/v1/    Auth · Clients · Contacts · Produits · Devis
│   │   │                      Factures · Avoirs · LignesAvoir
│   │   │                      Transmissions · AvoirTransmissionsPa
│   │   │                      EvenementsFacture · EvenementsAvoir · Dashboard
│   │   └── webhooks/          PaController (endpoint public signé)
│   │
│   ├── models/                Modèles ActiveRecord (Facture, Avoir,
│   │                          LigneAvoir, EvenementFacture, EvenementAvoir…)
│   │
│   ├── services/
│   │   ├── [SOCLE GELÉ]       FacturXXmlService · FacturXPackageService
│   │   │                      FactureConformiteService · FactureEmissionService
│   │   │                      FactureTotalsService
│   │   ├── [avoirs, voie b]   AvoirXmlService · AvoirPdfService
│   │   │                      AvoirTotalsService · AvoirConformiteService
│   │   │                      AvoirEmissionService · AvoirXmlStorageService
│   │   ├── [numérotation]     NumerotationService (générique facture/avoir)
│   │   ├── [stockage]         FacturXStorageService · FacturePdfService
│   │   └── [transmission]     TransmissionPaOrchestrationService (agnostique)
│   │                          PaStatusIngestionService · PaStatusMapper
│   │                          PaInboundNotificationResolver
│   │                          PaWebhookSignatureVerifier
│   │                          PaRequiresReviewCounter · PaPollingRelanceService
│   │                          FactureStatusTransitionPolicy
│   │
│   ├── serializers/           Blueprinter (Facture, Avoir, LigneAvoir,
│   │                          EvenementAvoir…) — acteur sans email
│   ├── policies/              Pundit — une policy par ressource (rôle + tenant)
│   ├── jobs/                  PaPollingScannerJob · PaPollTransmissionJob
│   ├── adapters/pa/           BaseAdapter · <Provider>Adapter · ChorusProAdapter
│   └── current.rb             ActiveSupport::CurrentAttributes (organisation…)
│
├── config/
│   ├── initializers/          cors · jwt · pundit · rack_attack (rate limiting)
│   ├── facturx/               [SOCLE GELÉ] profil ICC sRGB
│   └── routes.rb              namespace api/v1 + namespace webhooks
│
├── vendor/facturx/            [SOCLE GELÉ] XSD 1.09 · Schematron EN16931
└── storage/<env>/             Archives PDF/A-3 + XML, cloisonnées par environnement
    ├── factures/<id>/         (storage/development/, storage/test/…)
    └── avoirs/<id>/
\`\`\`

> **Convention de nommage** : modèles en français · certaines tables au singulier
> avec \`self.table_name\` (\`transmission_pa\`, \`evenement_facture\`,
> \`evenement_avoir\`) · \`app/policies/\` réservé à Pundit (les machines d'état
> métier vivent dans \`app/services/\`).

---

## 🎨 Frontend — Architecture

\`\`\`
frontend/src/
├── api/                axios.ts · endpoints.ts · queryClient.ts
│                       facturesApi · lignesFactureApi · evenementsFactureApi
│                       transmissionPaApi
│                       avoirsApi · lignesAvoirApi · evenementsAvoirApi
│                       avoirTransmissionPaApi
│
├── types/              auth · client · facture · devis · transmission · dashboard
│                       avoir · ligneAvoir · evenementAvoir
│
├── hooks/              useFactures · useClients · useDevis · useDashboard
│                       useTransmissions · useConformite
│
├── context/            AuthContext
├── lib/                schemas.ts (Zod) · formatters.ts (€, dates, SIRET)
│
├── components/
│   ├── landing/        Navbar · Hero · ProblemeSection · ConformiteSection · CtaFinal
│   ├── facture/        FactureForm · LigneFactureRow · ConformitePanel · TotauxBlock
│   │                   InvoiceDetailHeader · InvoiceLifecycleTimeline
│   │                   InvoiceEventHistory · InvoiceTransmissionSection
│   ├── avoir/          CreditNoteLifecycleTimeline · CreditNoteEventHistory
│   ├── modals/         ModalShell · ConfirmModal · LoginModal · RegisterModal
│   └── layout/         Sidebar · TopBar · AppShell
│
├── pages/
│   ├── HomePage                "/"
│   ├── DashboardPage           "/app"
│   ├── ClientsPage             "/app/clients"
│   ├── FacturesPage            "/app/factures"
│   ├── NewInvoicePage          "/app/factures/new"
│   ├── FactureDetailPage       "/app/factures/:id"   (+ bloc « Avoirs » + reste dû)
│   ├── NewCreditNotePage       création d'un avoir depuis une facture émise
│   ├── AvoirDetailPage         "/app/avoirs/:id"
│   ├── DevisPage               "/app/devis"
│   └── ParametresPage          "/app/parametres"
│
└── styles/             tokens.css (design tokens) · global.css
\`\`\`

> Les composants de la page détail facture (header, timeline, historique,
> transmission) sont **réutilisés ou généralisés** pour la page détail avoir —
> pas de duplication de logique, seulement un élargissement de type.

### DA (Direction Artistique)

| Token | Valeur | Usage |
|-------|--------|-------|
| Fond principal | \`#09090f\` | Fond de l'application |
| Fond card | \`rgba(255,255,255,0.02)\` | Cartes, panneaux |
| Border | \`rgba(255,255,255,0.06)\` | Séparateurs |
| Violet (marque) | \`#7c3aed\` | Identité Sereno, accents |
| **Ambre (avoir)** | \`--color-avoir\` | **Type de document « avoir » (badge, accents)** |
| Vert (conformité) | \`#10b981\` | Statut conforme / succès |
| Orange (attente) | \`#f59e0b\` | Statut en attente |
| Rouge (retard) | \`#ef4444\` | Statut en retard / erreur |
| Bleu (info) | \`#3b82f6\` | Information |
| Texte primaire | \`#f1f5f9\` | Titres, valeurs |
| Texte secondaire | \`#94a3b8\` | Labels |
| Texte muted | \`#475569\` | Mentions discrètes |

> **Distinction facture / avoir** : le violet est l'identité de Sereno, l'**ambre**
> signale un document de type *avoir*. Un avoir se distingue d'une facture par trois
> signaux dosés : couleur ambre, badge « AVOIR », et filigrane sur le PDF — sans
> jamais détourner les couleurs de statut.

---

## ⚙️ Moteur de conformité

Avant toute émission, le service \`FactureConformiteService\` valide la facture et renvoie la liste des contrôles (affichés en vert dans l'UI) :

- ✅ Numéro séquentiel attribué, sans trou
- ✅ Mentions obligatoires 2026 présentes (SIRET, TVA, identité émetteur/destinataire…)
- ✅ Format Factur-X généré et conforme (PDF/A-3 + CII)
- ✅ Destinataire identifié et routable sur la PA
- ✅ Cohérence TVA (taux, totaux, exonérations)
- ✅ Données du destinataire complètes
- ✅ Blocage des cas invalides (facture sans ligne, client archivé)

Tant qu'un contrôle échoue, le bouton **« Émettre & transmettre via la PA »** reste désactivé. Le contrôle est **bloquant côté service** — pas seulement dans l'UI.

---

## 📋 Roadmap

### ✅ V1 — MVP émission conforme *(terminé, audité 96/100)*
- [x] Auth JWT multi-tenant + rôles
- [x] CRUD Clients / Contacts (routage PA)
- [x] Création de facture + lignes + totaux (TVA agrégée)
- [x] Générateur Factur-X (PDF/A-3 + CII) — **validé veraPDF / XSD / Schematron**
- [x] Mentions France CTC / Flux 2 — **0 BR-FR restante (Mustang)**
- [x] Numérotation séquentielle protégée
- [x] Moteur de conformité pré-émission (bloquant)
- [x] Dashboard conformité + écran « facture en 2 clics »
- [x] CI/CD GitHub Actions (RSpec + RuboCop + build) verte sur \`main\`

### ✅ V1.1 — Transmission & cycle de vie *(terminée)*
- [x] Journal d'événements réel (\`créée\` / \`émise\`, append-only, dans la transaction)
- [x] API historique exposée + isolation multi-tenant testée
- [x] Timeline cycle de vie + panneau Historique (frontend)
- [x] Confirmation avant émission (action irréversible protégée)
- [x] Chiffrement des secrets PA (\`ActiveRecord::Encryption\`, clés en env, chiffré au repos prouvé)
- [x] Transmission via Plateforme Agréée (adapter + orchestration 3 phases, sandbox)
- [x] Pipeline d'ingestion des statuts entrants (5 résultats, garde temporelle, déduplication)
- [x] Polling automatique (backoff + jitter, pause/stop, base source de vérité)
- [x] Webhook PA entrant sécurisé (signature HMAC, anti-rejeu, rattachement scopé)
- [x] Supervision UI (badge \`requires_review\` persistant, relance d'un polling en pause)
- [x] Rate limiting de l'endpoint webhook (\`rack-attack\`, 60 req/min par IP + organisation)

### ✅ V1.2 — Correction légale : les avoirs *(terminée)*
- [x] Émission d'un avoir conforme — Factur-X **TypeCode 381** + référence **BT-25** à la facture corrigée, validé XSD
- [x] Conformité avoir (référence facture obligatoire, cohérence des montants cumulés)
- [x] API avoir + journal \`evenement_avoir\` append-only (isolation multi-tenant testée)
- [x] Transmission de l'avoir via PA (couloir d'ingestion rendu agnostique, sans duplication)
- [x] Gestion des lignes d'avoir + filigrane « AVOIR » sur le PDF (compatible PDF/A-3)
- [x] Frontend avoir (création par montant à créditer/ligne, page détail, navigation croisée, DA ambre)
- [x] Solde facture reflétant les avoirs émis (« reste dû » dérivé, TTC légal jamais modifié)
- [x] Stockage des archives cloisonné par environnement (fiabilité de l'archivage)

### ✅ B4 — Preuve de conformité automatisée en CI *(étages 1 & 2 livrés)*
- [x] Validateurs officiels **en CI à chaque push** : XSD + Schematron EN 16931 (Mustang) + PDF/A-3b (veraPDF), facture **et** avoir (standard + franchise), auto-tests négatifs permanents — France CTC/BR-FR reste hors CI (aucun scénario public, dette n°24)

### ⏳ V1.2+ — Automatisation
- [ ] Relances automatiques (jobs + e-mails)
- [ ] E-reporting B2C / international
- [ ] Exports comptables (FEC)
- [ ] Tests frontend (Vitest + Testing Library)
- [ ] Gestion des paiements (« payé / reste à payer », distinct du dû après avoirs)

### ⏳ V1.3 — Cycle commercial complet
- [ ] Devis → conversion en facture
- [ ] Portail destinataire

### ⏳ V1.4 — Secteur public & monétisation
- [ ] Chorus Pro (B2G)
- [ ] Abonnements SaaS (Gratuit / Pro)

### ⏳ V1.5 — Production
- [ ] Dockerfile + docker-compose prod
- [ ] Déploiement Kamal 2 + HTTPS
- [ ] Sauvegardes PostgreSQL + archivage légal

---

## 🚀 Démarrage (dev)

\`\`\`bash
# Backend
cd backend
bundle install
bin/rails db:create db:migrate db:seed
bin/rails s                      # http://localhost:3000

# Jobs
bin/jobs                         # Solid Queue

# Frontend
cd frontend
npm install
npm run dev                      # http://localhost:5173
\`\`\`

\`\`\`bash
# Tout via Docker
docker compose up --build
\`\`\`

> ⚙️ **Configuration** — copiez \`.env.example\` vers \`.env\` et renseignez vos variables locales. Les secrets (clé maître Rails, identifiants) ne sont **jamais** versionnés.

### Compte de démo
\`\`\`
Email    : demo@sereno.fr
Password : password
Rôle     : OWNER
Org      : Studio Démo
\`\`\`

---

## 🧪 Qualité & conformité (résumé)

| Contrôle | Statut |
|----------|--------|
| Tests backend (RSpec) | ✅ verts — 334+ examples, 0 failure |
| Lint backend (RuboCop) | ✅ no offenses |
| Audit dépendances (bundler-audit) | ✅ clean |
| Analyse statique sécurité (Brakeman) | ✅ 0 erreur |
| Lint + build frontend | ✅ verts (en local — **pas en CI**, dette n°25) |
| PDF/A-3b (veraPDF) | ✅ 146/146 — **re-prouvé en CI** (facture + avoir) |
| XML CII (XSD 1.09) | ✅ VALID — **re-prouvé en CI**, factures **et** avoirs (380/381) |
| Schematron EN 16931 | ✅ 0 failed-assert — **re-prouvé en CI** (facture + avoir, standard + franchise) |
| France CTC / Flux 2 (Mustang) | ⚠️ validé au gel — **hors CI**, aucun scénario public (dette n°24) |
| Isolation multi-tenant (API journal + webhook + avoirs) | ✅ testée (cross-tenant → 404 / rejet signé) |
| Chiffrement des secrets au repos | ✅ prouvé (lecture SQL brute ≠ clair) |
| Socle légal gelé | ✅ frontière versionnée (\`SOCLE_GELE.md\`), contrôle de non-régression à chaque sprint |

---

## 📦 Déploiement (DevOps)

- **Build** — image Docker multi-stage (Ruby slim + assets précompilés + police & profil ICC vendorés)
- **Deploy** — \`kamal deploy\` (zero-downtime, rollback intégré)
- **CI/CD** — GitHub Actions : \`rspec\` + \`rubocop\` + gate de conformité (XSD/Schematron/PDF-A) → déploiement sur tag
- **HTTPS** — Traefik (Let's Encrypt automatique)
- **Données** — PostgreSQL 16 + sauvegardes chiffrées quotidiennes
- **Archivage légal** — bucket dédié (factures conservées 10 ans)

---

## 👤 Auteur

<div align="center">

### Sébastien Cantrelle
**Développeur Full Stack · Artiste 2D/3D · Amiens, France**

[![Portfolio](https://img.shields.io/badge/Portfolio-spiritzen.github.io-7c3aed?style=flat-square)](https://spiritzen.github.io/portfolio/)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Sébastien_Cantrelle-0077B5?style=flat-square&logo=linkedin)](https://www.linkedin.com/in/sebastien-cantrelle-26b695106/)
[![GitHub](https://img.shields.io/badge/GitHub-Spiritzen-181717?style=flat-square&logo=github)](https://github.com/Spiritzen)

*Sereno · MIT License · 2026*

</div>
