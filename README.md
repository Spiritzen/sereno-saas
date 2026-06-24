<div align="center">

# 🛡️ Sereno

### La facturation électronique conforme, sans prise de tête
**Émettre · Transmettre · Suivre · Archiver**

[![Portfolio](https://img.shields.io/badge/Portfolio-Sébastien_Cantrelle-7c3aed?style=for-the-badge)](https://spiritzen.github.io/portfolio/)
[![GitHub](https://img.shields.io/badge/GitHub-Spiritzen-181717?style=for-the-badge&logo=github)](https://github.com/Spiritzen)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-0077B5?style=for-the-badge&logo=linkedin)](https://www.linkedin.com/in/sebastien-cantrelle-26b695106/)

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

## ✅ Statut du projet — Juin 2026

> Phase actuelle : **Conception terminée → développement du MVP (V1)**

| Couche | Statut | Détail |
|--------|--------|--------|
| Étude réglementaire (réforme 2026/2027) | ✅ **Complet** | Calendrier, formats, PA, e-reporting, sanctions, archivage |
| Direction artistique + maquettes UX | ✅ **Complet** | Dashboard conformité + écran « facture en 2 clics » validés |
| Modèle de données (22 entités) | ✅ **Complet** | Schéma + invariants légaux (immutabilité, numérotation) |
| Architecture Rails 8 (API) | ✅ **Complet** | Arborescence, services, adapters, jobs définis |
| Backend — Auth JWT multi-tenant | ⏳ **V1** | Login / Refresh / Logout + `id_organisation` dans le token |
| Backend — CRUD Clients + Contacts | ⏳ **V1** | Destinataires, SIRET, TVA, routage PA |
| Backend — Création de facture + lignes | ⏳ **V1** | Brouillon → émise, totaux HT/TVA/TTC |
| Backend — Générateur Factur-X | ⏳ **V1** | PDF/A-3 + CII XML embarqué |
| Backend — Numérotation séquentielle | ⏳ **V1** | Sans trou, protégée contre la concurrence |
| Backend — Moteur de conformité | ⏳ **V1** | Service de contrôle pré-émission |
| Frontend — Auth + Landing | ⏳ **V1** | Inscription, landing premium |
| Frontend — Dashboard conformité | ⏳ **V1** | KPIs + bandeau « vous êtes conforme » |
| Frontend — Facture en 2 clics | ⏳ **V1** | Écran de création + panneau conformité |
| Intégration Plateforme Agréée (PA) | ⏳ **V1.1** | Adapter API + suivi des statuts |
| Cycle de vie temps réel (14 statuts) | ⏳ **V1.1** | Journal d'événements + polling |
| Relances automatiques | ⏳ **V1.2** | Jobs Solid Queue + e-mails |
| E-reporting (B2C / international) | ⏳ **V1.2** | Lots de transmission |
| Devis + Avoirs (notes de crédit) | ⏳ **V1.3** | Conversion devis → facture, rectification légale |
| Portail destinataire | ⏳ **V1.3** | Le client reçoit et suit sa facture |
| Chorus Pro (secteur public B2G) | ⏳ **V1.4** | Adapter dédié |
| Facturation SaaS (abonnements) | ⏳ **V1.4** | Plans Gratuit / Pro |
| Déploiement production (Kamal 2) | ⏳ **V1.5** | VPS OVH/Hetzner + HTTPS + CI/CD |

---

## 🛠 Stack technique

| Couche | Technologie | Version / détail |
|--------|-------------|------------------|
| **Backend** | Ruby on Rails | 8 — mode API |
| | Ruby | 3.3+ |
| | Authentification | JWT (HttpOnly Cookies) + BCrypt |
| | Autorisation | Pundit — policies par rôle |
| | Multi-tenant | `ActiveSupport::CurrentAttributes` — `Current.organisation` |
| | Background jobs | Solid Queue (natif Rails 8, sans Redis) |
| | Cache / Cable | Solid Cache + Solid Cable |
| | Génération PDF | HexaPDF — PDF/A-3 |
| | XML métier | Nokogiri — CII / Factur-X / UBL |
| | API docs | rswag — OpenAPI / Swagger |
| **Base de données** | PostgreSQL | 16 |
| **Frontend** | React | 18 |
| | TypeScript | Strict (`.tsx` partout) |
| | Vite | 6 |
| | Tailwind CSS | v4 (`@tailwindcss/vite`) |
| | TanStack Query | Cache & état serveur |
| | React Hook Form + Zod | Validation des formulaires |
| | Axios | Intercepteur refresh token |
| | React Router | v7 |
| | Recharts | Graphes dashboard |
| **Conformité** | Format e-facture | Factur-X (PDF/A-3 + CII), UBL, CII |
| | Transmission | Plateforme Agréée (PA) via adapter |
| | Secteur public | Chorus Pro (B2G) |
| **Tests** | Backend | RSpec + FactoryBot + Faker |
| | Frontend | Vitest + Testing Library |
| **DevOps** | Conteneurs | Docker + docker-compose |
| | Déploiement | Kamal 2 |
| | CI/CD | GitHub Actions |
| | Reverse proxy | Traefik / Caddy (HTTPS auto) |
| | Hébergement | VPS OVH ou Hetzner |

---

## 🗄 Modèle de données

**22 entités** — UUID partout — **6 domaines** :

```
Auth & Tenant   → ORGANISATION · UTILISATEUR · SESSION · ABONNEMENT
CRM             → CLIENT · CONTACT
Catalogue       → PRODUIT · TAUX_TVA
Facturation     → DEVIS · LIGNE_DEVIS · FACTURE · LIGNE_FACTURE · ACOMPTE · AVOIR
Cycle de vie    → EVENEMENT_FACTURE · NUMEROTATION
Transmission    → PLATEFORME_AGREEE · TRANSMISSION_PA · E_REPORTING
Paiement        → PAIEMENT · RELANCE
```

### Entités clés

| Entité | Rôle | Invariant légal |
|--------|------|-----------------|
| `ORGANISATION` | L'entreprise émettrice (le client SaaS) | SIRET, régime TVA, mentions légales |
| `CLIENT` | Le **destinataire** de la facture | Routage PA, type (entreprise / particulier / public) |
| `FACTURE` | Document de facturation | **Immuable une fois émise** — corrigée uniquement par un AVOIR |
| `LIGNE_FACTURE` | Détail (désignation, qté, PU, TVA) | — |
| `AVOIR` | Note de crédit / rectification | Seul moyen légal de corriger une facture émise |
| `NUMEROTATION` | Registre séquentiel par org / année / type | **Séquence continue, sans trou** |
| `EVENEMENT_FACTURE` | Journal append-only du cycle de vie | Trace d'audit des statuts officiels |
| `PLATEFORME_AGREEE` | Config de la PA connectée | — |
| `TRANSMISSION_PA` | Envoi via la PA + accusés | Statuts officiels de la réforme |

### Migrations Rails

| Version | Description |
|---------|-------------|
| V1 | Init — Auth, Tenant, Clients, Catalogue |
| V2 | Facturation — Devis, Factures, Lignes, Acomptes, Avoirs |
| V3 | Numérotation séquentielle + contrainte d'unicité par séquence |
| V4 | Cycle de vie — `evenement_facture` (append-only) |
| V5 | Transmission — PA, e-reporting, accusés |
| V6 | Paiements + relances |
| V7 | Abonnement SaaS + index de performance |

---

## 🔄 Cycle de vie de la facture

Le cœur du produit : un suivi **temps réel** des statuts officiels imposés par la réforme. La facture vit, et l'utilisateur la voit vivre.

```
BROUILLON → ÉMISE → DÉPOSÉE (PA) → REÇUE → MISE À DISPOSITION
                                      ↓
                          APPROUVÉE  /  REFUSÉE  /  EN LITIGE
                                      ↓
                          ENCAISSÉE (paiement reçu)
                                      ↓
                          ARCHIVÉE (10 ans)
```

- **14 statuts** possibles, dont **4 obligatoires** : *Déposée*, *Refusée*, *Encaissement constaté*, *Paiement transmis*.
- Chaque changement d'état génère un `EVENEMENT_FACTURE` (journal d'audit inaltérable).
- Les statuts remontent de la PA via webhook ou polling (job Solid Queue).

---

## 🔐 Sécurité, multi-tenant & conformité

- **JWT HttpOnly Cookies** — access token 15 min + refresh 7 j
- **BCrypt** — zéro mot de passe en clair
- **`Current.organisation`** — `id_organisation` extrait du JWT, injecté dans chaque requête ; **tous les scopes filtrent par organisation**
- **Pundit** — autorisation fine par rôle
- **RGPD** — aucune fuite de données entre organisations possible
- **Immutabilité légale** — une facture émise ne peut **jamais** être modifiée ni supprimée ; toute correction passe par un `AVOIR`
- **Numérotation sans trou** — séquence PostgreSQL dédiée + advisory lock (jamais de `count + 1`)
- **Archivage 10 ans** — chaque facture émise (PDF/A-3 + XML) est archivée et horodatée

### 4 rôles

| Rôle | Périmètre |
|------|-----------|
| `SUPER_ADMIN` | Administration de la plateforme Sereno |
| `OWNER` | Propriétaire de l'organisation — tout : facturation, équipe, abonnement |
| `COMPTABLE` | Lecture finance + exports comptables (FEC) |
| `MEMBRE` | Création de devis et factures |

> Un **portail destinataire** (V1.3) permet au CLIENT de consulter et suivre ses factures reçues.

---

## 🏗 Architecture Backend (Rails 8 — API)

```
app/
├── controllers/
│   └── api/v1/    Auth · Clients · Contacts · Produits · Devis
│                  Factures · Avoirs · Transmissions · Paiements
│                  Dashboard · Webhooks (PA)
├── models/        22 modèles ActiveRecord + concerns (Tenantable, Auditable)
├── services/      FactureComplianceCheck · FacturXGenerator · NumerotationService
│                  EmissionService · PaTransmissionService · EReportingService
├── serializers/   Blueprinter — sérialisation JSON
├── policies/      Pundit — une policy par ressource
├── jobs/          RelanceJob · PaStatusPollJob · EReportingBatchJob · ArchivageJob
├── adapters/
│   └── pa/        BaseAdapter · <Provider>Adapter · ChorusProAdapter
├── lib/
│   └── factur_x/  CiiBuilder (Nokogiri) · PdfA3Embedder (HexaPDF)
└── current.rb     ActiveSupport::CurrentAttributes (organisation, utilisateur)
config/
├── initializers/  cors · jwt · pundit · current_tenant
└── routes.rb      namespace api/v1
```

---

## 🎨 Frontend — Architecture

```
src/
├── api/           axios.ts · endpoints.ts · queryClient.ts
├── types/         auth · client · facture · devis · transmission · dashboard
├── hooks/         useFactures · useClients · useDevis · useDashboard
│                  useTransmissions · useConformite
├── context/       AuthContext
├── lib/           schemas.ts (Zod) · formatters.ts (€, dates, SIRET)
├── components/
│   ├── landing/   Navbar · Hero · ProblemeSection · ConformiteSection · CtaFinal
│   ├── facture/   FactureForm · LigneFactureRow · ConformitePanel · TotauxBlock
│   ├── modals/    LoginModal · RegisterModal · ClientModal
│   └── layout/    Sidebar · TopBar · Layout
├── pages/
│   ├── HomePage.tsx           (route "/")
│   ├── DashboardPage.tsx      (route "/app")
│   ├── ClientsPage.tsx        (route "/app/clients")
│   ├── FacturesPage.tsx       (route "/app/factures")
│   ├── NouvelleFacturePage.tsx(route "/app/factures/new")
│   ├── DevisPage.tsx          (route "/app/devis")
│   └── ParametresPage.tsx     (route "/app/parametres")
└── index.css
```

### DA (Direction Artistique)

| Token | Valeur |
|-------|--------|
| Fond principal | `#09090f` |
| Fond card | `rgba(255,255,255,0.02)` |
| Border | `rgba(255,255,255,0.06)` |
| Violet (marque) | `#7c3aed` |
| Vert (conformité) | `#10b981` |
| Orange (attente) | `#f59e0b` |
| Rouge (retard) | `#ef4444` |
| Bleu (info) | `#3b82f6` |
| Texte primaire | `#f1f5f9` |
| Texte secondaire | `#94a3b8` |
| Texte muted | `#475569` |

---

## ⚙️ Moteur de conformité

Avant toute émission, le service `FactureComplianceCheck` valide la facture et renvoie la liste des contrôles (affichés en vert dans l'UI) :

- ✅ Numéro séquentiel attribué, sans trou
- ✅ Mentions obligatoires 2026 présentes (SIRET, TVA, identité émetteur/destinataire…)
- ✅ Format Factur-X généré et conforme (PDF/A-3 + CII)
- ✅ Destinataire identifié et routable sur la PA
- ✅ Cohérence TVA (taux, totaux, exonérations)
- ✅ Données du destinataire complètes

Tant qu'un contrôle échoue, le bouton **« Émettre & transmettre via la PA »** reste désactivé.

---

## 📋 Roadmap

### ⏳ V1 — MVP émission conforme
- [ ] Auth JWT multi-tenant + rôles
- [ ] CRUD Clients / Contacts (routage PA)
- [ ] Création de facture + lignes + totaux
- [ ] Générateur Factur-X (PDF/A-3 + CII)
- [ ] Numérotation séquentielle protégée
- [ ] Moteur de conformité pré-émission
- [ ] Dashboard conformité + écran « facture en 2 clics »

### ⏳ V1.1 — Transmission & cycle de vie
- [ ] Intégration Plateforme Agréée (adapter)
- [ ] Suivi temps réel des 14 statuts (webhook + polling)
- [ ] Journal d'événements (audit)

### ⏳ V1.2 — Automatisation
- [ ] Relances automatiques (jobs + e-mails)
- [ ] E-reporting B2C / international
- [ ] Exports comptables (FEC)

### ⏳ V1.3 — Cycle commercial complet
- [ ] Devis → conversion en facture
- [ ] Avoirs (notes de crédit / rectification)
- [ ] Portail destinataire

### ⏳ V1.4 — Secteur public & monétisation
- [ ] Chorus Pro (B2G)
- [ ] Abonnements SaaS (Gratuit / Pro)

### ⏳ V1.5 — Production
- [ ] Dockerfile + docker-compose prod
- [ ] Déploiement Kamal 2 + HTTPS
- [ ] CI/CD GitHub Actions
- [ ] Sauvegardes PostgreSQL + archivage légal

---

## 🚀 Démarrage (dev)

```bash
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
```

```bash
# Tout via Docker
docker compose up --build
```

### Compte de démo
```
Email    : demo@sereno.fr
Password : password
Rôle     : OWNER
Org       : Studio Démo
```

---

## 📦 Déploiement (DevOps)

- **Build** — image Docker multi-stage (Ruby slim + assets précompilés)
- **Deploy** — `kamal deploy` (zero-downtime, rollback intégré)
- **CI/CD** — GitHub Actions : `rspec` + `vitest` + `rubocop` + build → déploiement sur tag
- **HTTPS** — Traefik (Let's Encrypt automatique)
- **Données** — PostgreSQL 16 + sauvegardes chiffrées quotidiennes
- **Archivage légal** — bucket dédié (factures conservées 10 ans)

---

## 👤 Auteur

<div align="center">

### Sébastien Cantrelle
**Développeur Full Stack · Artiste 2D/3D · Strasbourg, France**

[![Portfolio](https://img.shields.io/badge/Portfolio-spiritzen.github.io-7c3aed?style=flat-square)](https://spiritzen.github.io/portfolio/)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Sébastien_Cantrelle-0077B5?style=flat-square&logo=linkedin)](https://www.linkedin.com/in/sebastien-cantrelle-26b695106/)
[![GitHub](https://img.shields.io/badge/GitHub-Spiritzen-181717?style=flat-square&logo=github)](https://github.com/Spiritzen)

*Sereno · MIT License · 2026*

</div>
