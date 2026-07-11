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
![Audit](https://img.shields.io/badge/audit-96.5%2F100_GREEN-10b981?style=flat-square)
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

> Phase actuelle : **MVP émission conforme validé** — socle légal gelé, cycle de conformité prouvé par validateurs officiels. Développement de la couche transmission & cycle de vie **en cours (V1.1)**.

Le moteur d'émission Factur-X (PDF/A-3 + XML CII) est **fonctionnel et prouvé conforme**. La note d'audit est de **96,5/100 (GREEN)** : socle légal gelé à 96/100 après quatre passages d'audit successifs et un delta conformité France CTC, plus un demi-point capitalisé sur la couche cycle de vie (journal d'événements réel, historique exposé et testé). Voir [Conformité prouvée](#-conformité-prouvée).

| Couche | Statut | Détail |
|--------|--------|--------|
| Étude réglementaire (réforme 2026/2027) | ✅ **Complet** | Calendrier, formats, PA, e-reporting, sanctions, archivage |
| Direction artistique + maquettes UX | ✅ **Complet** | Dashboard conformité + écran « facture en 2 clics » validés |
| Modèle de données (22 entités) | ✅ **Complet** | Schéma + invariants légaux (immutabilité, numérotation) |
| Architecture Rails 8 (API) | ✅ **Complet** | Arborescence, services, adapters, jobs définis |
| Backend — Auth JWT multi-tenant | ✅ **Complet** | Login / Refresh / Logout + \`id_organisation\` dans le token |
| Backend — CRUD Clients + Contacts | ✅ **Complet** | Destinataires, SIRET, TVA, routage PA |
| Backend — Création de facture + lignes | ✅ **Complet** | Brouillon → émise, totaux HT/TVA/TTC (TVA agrégée par taux) |
| Backend — Générateur Factur-X | ✅ **Complet** | PDF/A-3 + CII XML embarqué — **validé veraPDF / XSD / Schematron** |
| Backend — Numérotation séquentielle | ✅ **Complet** | Sans trou, protégée par advisory lock (concurrence) |
| Backend — Moteur de conformité | ✅ **Complet** | Contrôle pré-émission bloquant |
| Backend — Mentions France CTC (Flux 2) | ✅ **Complet** | BT-30/34/49, notes PMT/PMD/AAB, ProfileID, BusinessProcessID — **0 BR-FR restante (Mustang)** |
| Backend — Journal d'événements + API historique | ✅ **Complet** | Événements \`créée\` / \`émise\` append-only, API lecture scopée organisation, testée multi-tenant |
| Frontend — Auth + Landing | ✅ **Complet** | Inscription, landing premium |
| Frontend — Dashboard conformité | ✅ **Complet** | KPIs + greeting & échéance dynamiques |
| Frontend — Facture en 2 clics | ✅ **Complet** | Écran de création + panneau conformité |
| Frontend — Page détail facture (bandeau + timeline) | ✅ **Complet** | Bandeau premium + timeline cycle de vie + historique réel |
| Frontend — Page Paramètres | ✅ **Complet** | Placeholder honnête (domaines à venir) |
| CI/CD — GitHub Actions (RSpec, RuboCop, build) | ✅ **Complet** | Pipeline vert sur \`main\` |
| Validateurs de conformité en CI (veraPDF/Schematron) | ⏳ **V1.1** | Preuve de conformité automatisée à chaque push |
| Intégration Plateforme Agréée (PA) | ⏳ **V1.1** | Adapter API + suivi des statuts (sandbox) |
| Suivi temps réel des 14 statuts (webhook + polling) | ⏳ **V1.1** | Statuts externes remontés dans le journal |
| Avoirs (notes de crédit) | ⏳ **V1.2** | Rectification légale d'une facture émise |
| Relances automatiques | ⏳ **V1.2** | Jobs Solid Queue + e-mails |
| E-reporting (B2C / international) | ⏳ **V1.2** | Lots de transmission |
| Devis → facture · Portail destinataire | ⏳ **V1.3** | Conversion, suivi côté client |
| Chorus Pro (B2G) · Abonnements SaaS | ⏳ **V1.4** | Adapter dédié · Plans Gratuit / Pro |
| Déploiement production (Kamal 2) | ⏳ **V1.5** | VPS OVH/Hetzner + HTTPS + CI/CD |

---

## 🏅 Conformité prouvée

> Chez Sereno, la conformité n'est pas *affirmée*, elle est **prouvée par les validateurs officiels** — les mêmes que ceux utilisés par les Plateformes Agréées. Un « PDF qui s'ouvre » ne suffit pas : chaque facture générée franchit quatre niveaux de validation.

| Niveau | Outil | Résultat |
|--------|-------|----------|
| **PDF/A-3b** (ISO 19005-3) | veraPDF | ✅ **VALID** — 146/146 règles |
| **Structure XML** (CII D22B) | xmllint + XSD Factur-X 1.09 officiel | ✅ **VALID** |
| **Règles métier EN 16931** | Schematron officiel vendoré (Saxon/SchXslt) | ✅ **0 failed-assert** |
| **Profil France CTC / Flux 2** | Mustang CLI | ✅ **0 BR-FR restante** |

**Garanties vérifiées automatiquement :**
- **Round-trip** — le XML embarqué dans le PDF/A-3 est byte-identique au XML de référence (pas de pièce jointe vide ou divergente).
- **Cohérence PDF ↔ XML** — les totaux HT/TVA/TTC du PDF correspondent au centime au \`GrandTotalAmount\` du XML (règles BR-CO), calcul en \`BigDecimal\` avec arrondi \`ROUND_HALF_UP\`.
- **Assertion négative** — une facture non conforme (sans ligne, client archivé…) est **refusée** à l'émission : le pipeline sait aussi dire non.
- **Isolation multi-tenant testée** — l'API du journal d'événements est prouvée étanche : une organisation ne peut jamais lire les événements d'une autre (test d'isolation → 404, aucune donnée exposée).
- **Artefacts vendorés** — profil ICC sRGB et schémas officiels versionnés dans le dépôt, pour une image de production reproductible et indépendante de l'hôte.

> Le socle de conformité est **gelé** (\`tag v0.2.0-conformite-fr\`) : aucune modification du moteur légal sans re-validation par les quatre niveaux ci-dessus.

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
| **Tests** | Backend | RSpec + FactoryBot + Faker |
| | Frontend | Vitest + Testing Library |
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
Facturation     → DEVIS · LIGNE_DEVIS · FACTURE · LIGNE_FACTURE · ACOMPTE · AVOIR
Cycle de vie    → EVENEMENT_FACTURE · NUMEROTATION
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
| \`AVOIR\` | Note de crédit / rectification | Seul moyen légal de corriger une facture émise |
| \`NUMEROTATION\` | Registre séquentiel par org / année / type | **Séquence continue, sans trou** |
| \`EVENEMENT_FACTURE\` | Journal append-only du cycle de vie | Trace d'audit des statuts officiels |
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

> Les statuts de transmission (dépôt PA → encaissement) et leur remontée temps réel arrivent en **V1.1** ; ils alimenteront ce même journal.

---

## 🔐 Sécurité, multi-tenant & conformité

- **JWT HttpOnly Cookies** — access token 15 min + refresh 7 j (rotation)
- **BCrypt** — zéro mot de passe en clair
- **\`Current.organisation\`** — \`id_organisation\` extrait du JWT, injecté dans chaque requête ; **tous les scopes filtrent par organisation** (isolation explicite, pas de \`default_scope\` global — choix assumé pour une isolation testable et lisible)
- **Pundit** — autorisation fine par rôle
- **RGPD** — aucune fuite de données entre organisations possible ; l'isolation est **testée** (accès cross-tenant → 404, aucune donnée exposée)
- **Immutabilité légale** — une facture émise ne peut **jamais** être modifiée ni supprimée ; toute correction passe par un \`AVOIR\` (garde au niveau modèle via \`statut_in_database\`)
- **Journal append-only** — les événements de facture ne sont ni modifiables ni supprimables ; l'API ne les expose qu'en lecture (acteur limité à \`id\` + \`display_name\`, jamais l'email ni les URLs de fichiers)
- **Numérotation sans trou** — advisory lock PostgreSQL + verrou de ligne sur un compteur dédié, dans la transaction d'émission (jamais de \`count + 1\`)
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
app/
├── controllers/
│   └── api/v1/    Auth · Clients · Contacts · Produits · Devis
│                  Factures · Avoirs · Transmissions · Paiements
│                  Dashboard · Webhooks (PA)
├── models/        22 modèles ActiveRecord + concerns
├── services/      FactureConformiteService · FactureEmissionService
│                  FacturXXmlService · FacturePdfService · FacturXPackageService
│                  NumerotationService · FactureTotalsService
├── serializers/   Blueprinter — sérialisation JSON
├── policies/      Pundit — une policy par ressource
├── jobs/          RelanceJob · PaStatusPollJob · EReportingBatchJob · ArchivageJob
├── adapters/
│   └── pa/        BaseAdapter · <Provider>Adapter · ChorusProAdapter
├── vendor/
│   └── facturx/   XSD 1.09 · Schematron EN16931 · profil ICC sRGB (vendorés)
└── current.rb     ActiveSupport::CurrentAttributes (organisation, utilisateur)
config/
├── initializers/  cors · jwt · pundit
└── routes.rb      namespace api/v1
\`\`\`

---

## 🎨 Frontend — Architecture

\`\`\`
src/
├── api/           axios.ts · endpoints.ts · queryClient.ts
│                  evenementsFactureApi.ts
├── types/         auth · client · facture · devis · transmission · dashboard
├── hooks/         useFactures · useClients · useDevis · useDashboard
│                  useTransmissions · useConformite
├── context/       AuthContext
├── lib/           schemas.ts (Zod) · formatters.ts (€, dates, SIRET)
├── components/
│   ├── landing/   Navbar · Hero · ProblemeSection · ConformiteSection · CtaFinal
│   ├── facture/   FactureForm · LigneFactureRow · ConformitePanel · TotauxBlock
│   │              InvoiceDetailHeader · InvoiceLifecycleTimeline · InvoiceEventHistory
│   ├── modals/    ModalShell · ConfirmModal · LoginModal · RegisterModal · ClientModal
│   └── layout/    Sidebar · TopBar · AppShell
├── pages/
│   ├── HomePage.tsx           (route "/")
│   ├── DashboardPage.tsx      (route "/app")
│   ├── ClientsPage.tsx        (route "/app/clients")
│   ├── FacturesPage.tsx       (route "/app/factures")
│   ├── NewInvoicePage.tsx     (route "/app/factures/new")
│   ├── FactureDetailPage.tsx  (route "/app/factures/:id")
│   ├── DevisPage.tsx          (route "/app/devis")
│   └── ParametresPage.tsx     (route "/app/parametres")
└── index.css
\`\`\`

### DA (Direction Artistique)

| Token | Valeur |
|-------|--------|
| Fond principal | \`#09090f\` |
| Fond card | \`rgba(255,255,255,0.02)\` |
| Border | \`rgba(255,255,255,0.06)\` |
| Violet (marque) | \`#7c3aed\` |
| Vert (conformité) | \`#10b981\` |
| Orange (attente) | \`#f59e0b\` |
| Rouge (retard) | \`#ef4444\` |
| Bleu (info) | \`#3b82f6\` |
| Texte primaire | \`#f1f5f9\` |
| Texte secondaire | \`#94a3b8\` |
| Texte muted | \`#475569\` |

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

### 🚧 V1.1 — Preuve automatisée, transmission & cycle de vie *(en cours)*
- [x] Journal d'événements réel (\`créée\` / \`émise\`, append-only, dans la transaction)
- [x] API historique exposée + isolation multi-tenant testée
- [x] Timeline cycle de vie + panneau Historique (frontend)
- [x] Confirmation avant émission (action irréversible protégée)
- [ ] Validateurs de conformité (veraPDF + Schematron) **bloquants en CI**
- [ ] Intégration Plateforme Agréée (adapter, sandbox)
- [ ] Suivi temps réel des 14 statuts (webhook + polling)

### ⏳ V1.2 — Correction légale & automatisation
- [ ] Avoirs (notes de crédit / rectification, type 381)
- [ ] Relances automatiques (jobs + e-mails)
- [ ] E-reporting B2C / international
- [ ] Exports comptables (FEC)

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
| Tests backend (RSpec) | ✅ verts — 110 examples, 0 failure |
| Lint backend (RuboCop) | ✅ no offenses |
| Audit dépendances (bundler-audit) | ✅ clean |
| Lint + build frontend | ✅ verts |
| PDF/A-3b (veraPDF) | ✅ VALID (146/146) |
| XML CII (XSD 1.09) | ✅ VALID |
| Schematron EN 16931 | ✅ 0 failed-assert |
| France CTC / Flux 2 (Mustang) | ✅ 0 BR-FR restante |
| Isolation multi-tenant (API journal) | ✅ testée (cross-tenant → 404) |
| **Audit** | ✅ **96,5/100 — GREEN** |

---

## 📦 Déploiement (DevOps)

- **Build** — image Docker multi-stage (Ruby slim + assets précompilés + police & profil ICC vendorés)
- **Deploy** — \`kamal deploy\` (zero-downtime, rollback intégré)
- **CI/CD** — GitHub Actions : \`rspec\` + \`rubocop\` + build front → déploiement sur tag
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
