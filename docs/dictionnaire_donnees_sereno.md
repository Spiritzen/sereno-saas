# Dictionnaire de données — Sereno

> Dictionnaire de données relationnel des **22 entités** de Sereno (SaaS de facturation électronique).
> Conçu pour alimenter **Looping** (MCD/MLD) et la documentation. Voir aussi [README.md](./README.md) et [CONTEXT.md](./CONTEXT.md).

---

## Conventions

**Clés**
- Clé primaire : `id` de type `UUID` sur chaque table.
- Clé étrangère : `<entite>_id` (convention Rails). Notée `FK → table.id`.
- Multi-tenant : `organisation_id` présent sur **toutes** les tables métier (isolation RGPD), sauf `organisation`.

**Types utilisés**
| Type | Équivalent PostgreSQL | Usage |
|------|----------------------|-------|
| `UUID` | `uuid` (ou `CHAR(36)`) | Identifiants |
| `VARCHAR(n)` | `varchar(n)` | Chaînes courtes |
| `TEXT` | `text` | Texte long |
| `SMALLINT` / `INTEGER` | idem | Entiers |
| `NUMERIC(p,s)` | `numeric(p,s)` | Montants (12,2) et taux (5,2) |
| `BOOLEAN` | `boolean` | Vrai/Faux |
| `DATE` | `date` | Dates sans heure |
| `TIMESTAMP` | `timestamptz` | Date + heure (= DATETIME) |
| `JSONB` | `jsonb` | Payloads structurés |
| `ENUM` | `varchar` + `CHECK` | Listes de valeurs (valeurs précisées en commentaire) |

**Colonnes d'audit** (sur chaque table sauf mention contraire)
- `created_at` `TIMESTAMP` `NOT NULL DEFAULT now()` — date de création
- `updated_at` `TIMESTAMP` `NOT NULL DEFAULT now()` — date de dernière modification

---

# DOMAINE 1 — AUTH & TENANT

## Table : `organisation`
> L'entreprise émettrice = le client SaaS. Racine du multi-tenant.

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| raison_sociale | VARCHAR(255) | NOT NULL | Nom légal de l'entreprise |
| forme_juridique | VARCHAR(50) | NULL | EI, EURL, SASU, SARL… |
| siret | VARCHAR(14) | NOT NULL, UNIQUE, CHECK (length = 14) | Identifiant établissement |
| numero_tva | VARCHAR(20) | NULL | N° TVA intracommunautaire |
| regime_tva | VARCHAR(20) | NOT NULL, DEFAULT 'franchise' | ENUM : franchise, reel_simplifie, reel_normal |
| adresse_ligne1 | VARCHAR(255) | NOT NULL | Adresse |
| adresse_ligne2 | VARCHAR(255) | NULL | Complément |
| code_postal | VARCHAR(10) | NOT NULL | Code postal |
| ville | VARCHAR(100) | NOT NULL | Ville |
| pays | VARCHAR(2) | NOT NULL, DEFAULT 'FR' | Code ISO 3166-1 |
| email | VARCHAR(255) | NOT NULL | Email de contact |
| telephone | VARCHAR(20) | NULL | Téléphone |
| iban | VARCHAR(34) | NULL | Pour mentions de paiement |
| mentions_legales | TEXT | NULL | Mentions par défaut sur les factures |
| identifiant_pa | VARCHAR(100) | NULL | Identifiant de routage sur la PA |
| logo_url | VARCHAR(500) | NULL | Logo (entête de facture) |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |

## Table : `utilisateur`
> Compte utilisateur rattaché à une organisation, porteur d'un rôle.

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| organisation_id | UUID | **FK → organisation.id**, NOT NULL | Tenant |
| email | VARCHAR(255) | NOT NULL, UNIQUE | Identifiant de connexion |
| mot_de_passe_hash | VARCHAR(255) | NOT NULL | Hash BCrypt |
| nom | VARCHAR(100) | NOT NULL | Nom |
| prenom | VARCHAR(100) | NOT NULL | Prénom |
| role | VARCHAR(20) | NOT NULL, DEFAULT 'membre' | ENUM : super_admin, owner, comptable, membre |
| actif | BOOLEAN | NOT NULL, DEFAULT true | Compte actif |
| derniere_connexion_at | TIMESTAMP | NULL | Dernière connexion |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |

## Table : `session`
> Refresh tokens (rotation, expiration, révocation).

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| utilisateur_id | UUID | **FK → utilisateur.id**, NOT NULL | Propriétaire de la session |
| organisation_id | UUID | **FK → organisation.id**, NOT NULL | Tenant |
| refresh_token_hash | VARCHAR(255) | NOT NULL, UNIQUE | Hash du refresh token |
| user_agent | VARCHAR(255) | NULL | Navigateur/appareil |
| ip_adresse | VARCHAR(45) | NULL | IPv4 ou IPv6 |
| expire_at | TIMESTAMP | NOT NULL | Expiration (≈ 7 j) |
| revoque_at | TIMESTAMP | NULL | Date de révocation (logout) |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |

## Table : `abonnement`
> Abonnement SaaS de l'organisation (plan, période, facturation).

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| organisation_id | UUID | **FK → organisation.id**, NOT NULL | Tenant |
| plan | VARCHAR(20) | NOT NULL, DEFAULT 'gratuit' | ENUM : gratuit, pro |
| statut | VARCHAR(20) | NOT NULL, DEFAULT 'en_essai' | ENUM : en_essai, actif, suspendu, annule |
| date_debut | DATE | NOT NULL | Début de période |
| date_fin | DATE | NULL | Fin (NULL = en cours) |
| prix_mensuel | NUMERIC(8,2) | NULL | Tarif mensuel |
| id_stripe | VARCHAR(100) | NULL | Référence prestataire de paiement |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |

---

# DOMAINE 2 — CRM (DESTINATAIRES)

## Table : `client`
> Le destinataire d'une facture. Son `type` détermine e-facture (B2B/B2G) vs e-reporting (B2C).

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| organisation_id | UUID | **FK → organisation.id**, NOT NULL | Tenant |
| type | VARCHAR(20) | NOT NULL, DEFAULT 'entreprise' | ENUM : entreprise, particulier, public |
| raison_sociale | VARCHAR(255) | NOT NULL | Nom de l'entreprise ou du particulier |
| siret | VARCHAR(14) | NULL | Requis si entreprise/public |
| numero_tva | VARCHAR(20) | NULL | N° TVA intracommunautaire |
| adresse_ligne1 | VARCHAR(255) | NOT NULL | Adresse |
| adresse_ligne2 | VARCHAR(255) | NULL | Complément |
| code_postal | VARCHAR(10) | NOT NULL | Code postal |
| ville | VARCHAR(100) | NOT NULL | Ville |
| pays | VARCHAR(2) | NOT NULL, DEFAULT 'FR' | Code ISO |
| email | VARCHAR(255) | NULL | Email |
| telephone | VARCHAR(20) | NULL | Téléphone |
| identifiant_routage_pa | VARCHAR(100) | NULL | Routage sur la PA (requis B2B/B2G) |
| statut | VARCHAR(20) | NOT NULL, DEFAULT 'actif' | ENUM : actif, archive |
| notes | TEXT | NULL | Notes internes |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |

## Table : `contact`
> Personne physique rattachée à un client.

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| organisation_id | UUID | **FK → organisation.id**, NOT NULL | Tenant |
| client_id | UUID | **FK → client.id**, NOT NULL | Client rattaché |
| nom | VARCHAR(100) | NOT NULL | Nom |
| prenom | VARCHAR(100) | NULL | Prénom |
| fonction | VARCHAR(100) | NULL | Poste |
| email | VARCHAR(255) | NULL | Email |
| telephone | VARCHAR(20) | NULL | Téléphone |
| principal | BOOLEAN | NOT NULL, DEFAULT false | Contact principal |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |

---

# DOMAINE 3 — CATALOGUE

## Table : `produit`
> Prestation/produit réutilisable pour pré-remplir les lignes.

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| organisation_id | UUID | **FK → organisation.id**, NOT NULL | Tenant |
| taux_tva_id | UUID | **FK → taux_tva.id**, NULL | Taux de TVA par défaut |
| designation | VARCHAR(255) | NOT NULL | Libellé |
| description | TEXT | NULL | Description détaillée |
| prix_unitaire_ht | NUMERIC(12,2) | NOT NULL, CHECK (>= 0) | Prix unitaire HT |
| unite | VARCHAR(20) | NULL, DEFAULT 'unité' | unité, heure, jour, forfait |
| actif | BOOLEAN | NOT NULL, DEFAULT true | Visible au catalogue |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |

## Table : `taux_tva`
> Taux de TVA et mention d'exonération éventuelle.

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| organisation_id | UUID | **FK → organisation.id**, NOT NULL | Tenant |
| libelle | VARCHAR(50) | NOT NULL | Ex. « Taux normal 20 % » |
| taux | NUMERIC(5,2) | NOT NULL, CHECK (>= 0) | Ex. 20.00, 10.00, 5.50, 2.10, 0.00 |
| mention_exoneration | VARCHAR(255) | NULL | Ex. « TVA non applicable, art. 293 B du CGI » |
| par_defaut | BOOLEAN | NOT NULL, DEFAULT false | Taux par défaut de l'organisation |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |

---

# DOMAINE 4 — FACTURATION

## Table : `devis`
> Proposition commerciale, convertible en facture.

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| organisation_id | UUID | **FK → organisation.id**, NOT NULL | Tenant |
| client_id | UUID | **FK → client.id**, NOT NULL | Destinataire |
| numero | VARCHAR(30) | NULL | Attribué à l'envoi (NULL si brouillon) |
| statut | VARCHAR(20) | NOT NULL, DEFAULT 'brouillon' | ENUM : brouillon, envoye, accepte, refuse, expire |
| objet | VARCHAR(255) | NULL | Objet du devis |
| date_emission | DATE | NULL | Date d'envoi |
| date_validite | DATE | NULL | Date limite de validité |
| total_ht | NUMERIC(12,2) | NOT NULL, DEFAULT 0 | Total HT |
| total_tva | NUMERIC(12,2) | NOT NULL, DEFAULT 0 | Total TVA |
| total_ttc | NUMERIC(12,2) | NOT NULL, DEFAULT 0 | Total TTC |
| conditions | TEXT | NULL | Conditions commerciales |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |

## Table : `ligne_devis`
> Ligne d'un devis.

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| organisation_id | UUID | **FK → organisation.id**, NOT NULL | Tenant |
| devis_id | UUID | **FK → devis.id**, NOT NULL | Devis parent |
| produit_id | UUID | **FK → produit.id**, NULL | Produit source (optionnel) |
| designation | VARCHAR(255) | NOT NULL | Libellé |
| quantite | NUMERIC(10,2) | NOT NULL, DEFAULT 1 | Quantité |
| prix_unitaire_ht | NUMERIC(12,2) | NOT NULL | PU HT |
| taux_tva | NUMERIC(5,2) | NOT NULL | Taux figé sur la ligne |
| total_ht | NUMERIC(12,2) | NOT NULL | quantite × PU HT |
| position | INTEGER | NOT NULL, DEFAULT 0 | Ordre d'affichage |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |

## Table : `facture`
> Document de facturation. **IMMUABLE dès l'émission** (statut ≠ brouillon).

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| organisation_id | UUID | **FK → organisation.id**, NOT NULL | Tenant |
| client_id | UUID | **FK → client.id**, NOT NULL | Destinataire |
| devis_id | UUID | **FK → devis.id**, NULL | Devis d'origine (si conversion) |
| numero | VARCHAR(30) | NULL, UNIQUE (organisation_id, numero) | Séquentiel sans trou ; NULL tant que brouillon |
| type_document | VARCHAR(20) | NOT NULL, DEFAULT 'facture' | ENUM : facture, acompte |
| statut | VARCHAR(30) | NOT NULL, DEFAULT 'brouillon' | ENUM cycle de vie (voir § statuts) |
| date_emission | DATE | NULL | Figée à l'émission |
| date_echeance | DATE | NULL | Échéance de paiement |
| total_ht | NUMERIC(12,2) | NOT NULL, DEFAULT 0 | Total HT |
| total_tva | NUMERIC(12,2) | NOT NULL, DEFAULT 0 | Total TVA |
| total_ttc | NUMERIC(12,2) | NOT NULL, DEFAULT 0 | Total TTC |
| montant_paye | NUMERIC(12,2) | NOT NULL, DEFAULT 0 | Cumul des paiements |
| devise | VARCHAR(3) | NOT NULL, DEFAULT 'EUR' | Code ISO 4217 |
| format | VARCHAR(20) | NOT NULL, DEFAULT 'factur_x' | ENUM : factur_x, ubl, cii |
| mentions | TEXT | NULL | Mentions spécifiques |
| conditions_paiement | VARCHAR(255) | NULL | Conditions de règlement |
| pdf_url | VARCHAR(500) | NULL | PDF/A-3 archivé |
| xml_url | VARCHAR(500) | NULL | CII archivé |
| emise_at | TIMESTAMP | NULL | Horodatage d'émission (immuabilité) |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |

## Table : `ligne_facture`
> Ligne d'une facture. Montants et taux **figés** (immutabilité).

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| organisation_id | UUID | **FK → organisation.id**, NOT NULL | Tenant |
| facture_id | UUID | **FK → facture.id**, NOT NULL | Facture parente |
| produit_id | UUID | **FK → produit.id**, NULL | Produit source (optionnel) |
| designation | VARCHAR(255) | NOT NULL | Libellé |
| quantite | NUMERIC(10,2) | NOT NULL, DEFAULT 1 | Quantité |
| prix_unitaire_ht | NUMERIC(12,2) | NOT NULL | PU HT |
| taux_tva | NUMERIC(5,2) | NOT NULL | Taux figé sur la ligne |
| montant_tva | NUMERIC(12,2) | NOT NULL | Montant TVA de la ligne |
| total_ht | NUMERIC(12,2) | NOT NULL | Total HT ligne |
| total_ttc | NUMERIC(12,2) | NOT NULL | Total TTC ligne |
| position | INTEGER | NOT NULL, DEFAULT 0 | Ordre d'affichage |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |

## Table : `acompte`
> Facture/échéance d'acompte, déductible de la facture finale.

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| organisation_id | UUID | **FK → organisation.id**, NOT NULL | Tenant |
| client_id | UUID | **FK → client.id**, NOT NULL | Destinataire |
| facture_id | UUID | **FK → facture.id**, NULL | Facture finale rattachée |
| devis_id | UUID | **FK → devis.id**, NULL | Devis d'origine |
| numero | VARCHAR(30) | NULL | Numéro d'acompte |
| pourcentage | NUMERIC(5,2) | NULL | % du total |
| montant_ht | NUMERIC(12,2) | NOT NULL | Montant HT |
| montant_tva | NUMERIC(12,2) | NOT NULL | Montant TVA |
| montant_ttc | NUMERIC(12,2) | NOT NULL | Montant TTC |
| date_emission | DATE | NULL | Date d'émission |
| statut | VARCHAR(20) | NOT NULL, DEFAULT 'brouillon' | ENUM : brouillon, emis, encaisse, deduit |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |

## Table : `avoir`
> Note de crédit / facture rectificative. **Seul moyen légal de corriger une facture émise.**

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| organisation_id | UUID | **FK → organisation.id**, NOT NULL | Tenant |
| facture_id | UUID | **FK → facture.id**, NOT NULL | Facture corrigée |
| client_id | UUID | **FK → client.id**, NOT NULL | Destinataire |
| numero | VARCHAR(30) | NULL, UNIQUE (organisation_id, numero) | Séquentiel sans trou |
| motif | VARCHAR(255) | NOT NULL | Raison de l'avoir |
| statut | VARCHAR(30) | NOT NULL, DEFAULT 'brouillon' | ENUM cycle de vie (comme facture) |
| date_emission | DATE | NULL | Figée à l'émission |
| total_ht | NUMERIC(12,2) | NOT NULL, DEFAULT 0 | Total HT (montant crédité) |
| total_tva | NUMERIC(12,2) | NOT NULL, DEFAULT 0 | Total TVA |
| total_ttc | NUMERIC(12,2) | NOT NULL, DEFAULT 0 | Total TTC |
| pdf_url | VARCHAR(500) | NULL | PDF/A-3 archivé |
| xml_url | VARCHAR(500) | NULL | CII archivé |
| emis_at | TIMESTAMP | NULL | Horodatage d'émission |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |

## Table : `ligne_avoir`
> Ligne d'un avoir (montants figés).

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| organisation_id | UUID | **FK → organisation.id**, NOT NULL | Tenant |
| avoir_id | UUID | **FK → avoir.id**, NOT NULL | Avoir parent |
| designation | VARCHAR(255) | NOT NULL | Libellé |
| quantite | NUMERIC(10,2) | NOT NULL, DEFAULT 1 | Quantité |
| prix_unitaire_ht | NUMERIC(12,2) | NOT NULL | PU HT |
| taux_tva | NUMERIC(5,2) | NOT NULL | Taux figé |
| total_ht | NUMERIC(12,2) | NOT NULL | Total HT ligne |
| position | INTEGER | NOT NULL, DEFAULT 0 | Ordre d'affichage |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |

---

# DOMAINE 5 — CYCLE DE VIE & NUMÉROTATION

## Table : `evenement_facture`
> Journal **append-only** des changements de statut (trace d'audit). **Aucun UPDATE/DELETE — pas d'`updated_at`.**

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| organisation_id | UUID | **FK → organisation.id**, NOT NULL | Tenant |
| facture_id | UUID | **FK → facture.id**, NOT NULL | Facture concernée |
| utilisateur_id | UUID | **FK → utilisateur.id**, NULL | Auteur (si déclencheur interne) |
| statut | VARCHAR(30) | NOT NULL | Statut atteint (ENUM cycle de vie) |
| source | VARCHAR(20) | NOT NULL, DEFAULT 'interne' | ENUM : interne, pa, webhook |
| code_statut_pa | VARCHAR(50) | NULL | Code officiel remonté par la PA |
| payload | JSONB | NULL | Données brutes de l'événement |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | Horodatage (pas d'`updated_at`) |

## Table : `numerotation`
> Compteur séquentiel par organisation / type / année. Incrément protégé par **advisory lock** — jamais `count + 1`.

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| organisation_id | UUID | **FK → organisation.id**, NOT NULL | Tenant |
| type_document | VARCHAR(20) | NOT NULL | ENUM : facture, avoir, acompte, devis |
| annee | INTEGER | NOT NULL | Année de la séquence |
| prefixe | VARCHAR(20) | NULL | Ex. « FAC-2026- » |
| dernier_numero | INTEGER | NOT NULL, DEFAULT 0 | Dernier numéro attribué |
| — | — | UNIQUE (organisation_id, type_document, annee) | Une séquence par combinaison |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |

---

# DOMAINE 6 — TRANSMISSION & REPORTING

## Table : `plateforme_agreee`
> Configuration de la PA connectée à l'organisation (1 PA par organisation).

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| organisation_id | UUID | **FK → organisation.id**, NOT NULL, UNIQUE | Une seule PA active par organisation |
| fournisseur | VARCHAR(50) | NOT NULL | Nom du fournisseur de PA |
| type | VARCHAR(20) | NOT NULL, DEFAULT 'pa' | ENUM : pa, chorus_pro |
| api_url | VARCHAR(255) | NOT NULL | Endpoint de l'API |
| identifiant_compte | VARCHAR(255) | NULL | Identifiant du compte sur la PA |
| credentials_chiffres | TEXT | NULL | Secrets chiffrés (Rails encrypted) |
| statut | VARCHAR(20) | NOT NULL, DEFAULT 'connecte' | ENUM : connecte, deconnecte, erreur |
| connecte_at | TIMESTAMP | NULL | Date de connexion |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |

## Table : `transmission_pa`
> Une tentative d'envoi/réception via la PA + accusés et statuts officiels.

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| organisation_id | UUID | **FK → organisation.id**, NOT NULL | Tenant |
| facture_id | UUID | **FK → facture.id**, NULL | Facture transmise |
| avoir_id | UUID | **FK → avoir.id**, NULL | Avoir transmis |
| plateforme_agreee_id | UUID | **FK → plateforme_agreee.id**, NOT NULL | PA utilisée |
| direction | VARCHAR(10) | NOT NULL, DEFAULT 'sortant' | ENUM : sortant, entrant |
| statut | VARCHAR(30) | NOT NULL, DEFAULT 'en_attente' | ENUM : en_attente, depose, accepte, rejete, erreur |
| format | VARCHAR(20) | NOT NULL, DEFAULT 'factur_x' | ENUM : factur_x, ubl, cii |
| identifiant_pa | VARCHAR(100) | NULL | ID renvoyé par la PA |
| accuse_reception | JSONB | NULL | Accusé(s) de la PA |
| message_erreur | TEXT | NULL | Détail en cas d'erreur |
| transmis_at | TIMESTAMP | NULL | Date de transmission |
| — | — | CHECK (facture_id IS NOT NULL OR avoir_id IS NOT NULL) | Un document cible obligatoire |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |

## Table : `e_reporting`
> Lot de données de transaction/paiement transmis (B2C, international).

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| organisation_id | UUID | **FK → organisation.id**, NOT NULL | Tenant |
| type | VARCHAR(20) | NOT NULL | ENUM : transactions, paiements |
| periode_debut | DATE | NOT NULL | Début de période |
| periode_fin | DATE | NOT NULL | Fin de période |
| statut | VARCHAR(20) | NOT NULL, DEFAULT 'en_attente' | ENUM : en_attente, transmis, accepte, rejete |
| nb_operations | INTEGER | NOT NULL, DEFAULT 0 | Nombre d'opérations |
| montant_total | NUMERIC(14,2) | NOT NULL, DEFAULT 0 | Montant total du lot |
| payload | JSONB | NULL | Données transmises |
| transmis_at | TIMESTAMP | NULL | Date de transmission |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |

---

# DOMAINE 7 — PAIEMENT

## Table : `paiement`
> Encaissement rattaché à une facture.

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| organisation_id | UUID | **FK → organisation.id**, NOT NULL | Tenant |
| facture_id | UUID | **FK → facture.id**, NOT NULL | Facture réglée |
| montant | NUMERIC(12,2) | NOT NULL, CHECK (> 0) | Montant encaissé |
| methode | VARCHAR(20) | NOT NULL | ENUM : virement, carte, cheque, especes, prelevement |
| date_paiement | DATE | NOT NULL | Date de l'encaissement |
| reference | VARCHAR(100) | NULL | Référence (transaction, chèque…) |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |

## Table : `relance`
> Relance automatique d'une facture impayée.

| Attribut | Type | Contraintes | Commentaire |
|----------|------|-------------|-------------|
| id | UUID | **PK** | Identifiant |
| organisation_id | UUID | **FK → organisation.id**, NOT NULL | Tenant |
| facture_id | UUID | **FK → facture.id**, NOT NULL | Facture relancée |
| niveau | SMALLINT | NOT NULL, DEFAULT 1 | 1ʳᵉ, 2ᵉ, 3ᵉ relance |
| canal | VARCHAR(20) | NOT NULL, DEFAULT 'email' | ENUM : email, courrier |
| statut | VARCHAR(20) | NOT NULL, DEFAULT 'planifiee' | ENUM : planifiee, envoyee, echec |
| date_planifiee | DATE | NOT NULL | Date prévue d'envoi |
| envoyee_at | TIMESTAMP | NULL | Date d'envoi effectif |
| created_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT now() | — |

---

# Récapitulatif des clés étrangères (pour le MCD)

| Table source | Clé étrangère | Table cible | Cardinalité (côté source) |
|--------------|---------------|-------------|----------------------------|
| utilisateur | organisation_id | organisation | (1,1) → (0,n) |
| session | utilisateur_id | utilisateur | (1,1) → (0,n) |
| session | organisation_id | organisation | (1,1) → (0,n) |
| abonnement | organisation_id | organisation | (1,1) → (0,n) |
| client | organisation_id | organisation | (1,1) → (0,n) |
| contact | client_id | client | (1,1) → (0,n) |
| contact | organisation_id | organisation | (1,1) → (0,n) |
| produit | taux_tva_id | taux_tva | (0,1) → (0,n) |
| produit | organisation_id | organisation | (1,1) → (0,n) |
| taux_tva | organisation_id | organisation | (1,1) → (0,n) |
| devis | client_id | client | (1,1) → (0,n) |
| devis | organisation_id | organisation | (1,1) → (0,n) |
| ligne_devis | devis_id | devis | (1,1) → (1,n) |
| ligne_devis | produit_id | produit | (0,1) → (0,n) |
| facture | client_id | client | (1,1) → (0,n) |
| facture | devis_id | devis | (0,1) → (0,1) |
| facture | organisation_id | organisation | (1,1) → (0,n) |
| ligne_facture | facture_id | facture | (1,1) → (1,n) |
| ligne_facture | produit_id | produit | (0,1) → (0,n) |
| acompte | client_id | client | (1,1) → (0,n) |
| acompte | facture_id | facture | (0,1) → (0,n) |
| acompte | devis_id | devis | (0,1) → (0,n) |
| avoir | facture_id | facture | (1,1) → (0,n) |
| avoir | client_id | client | (1,1) → (0,n) |
| ligne_avoir | avoir_id | avoir | (1,1) → (1,n) |
| evenement_facture | facture_id | facture | (1,1) → (1,n) |
| evenement_facture | utilisateur_id | utilisateur | (0,1) → (0,n) |
| numerotation | organisation_id | organisation | (1,1) → (0,n) |
| plateforme_agreee | organisation_id | organisation | (1,1) → (0,1) |
| transmission_pa | facture_id | facture | (0,1) → (0,n) |
| transmission_pa | avoir_id | avoir | (0,1) → (0,n) |
| transmission_pa | plateforme_agreee_id | plateforme_agreee | (1,1) → (0,n) |
| e_reporting | organisation_id | organisation | (1,1) → (0,n) |
| paiement | facture_id | facture | (1,1) → (0,n) |
| relance | facture_id | facture | (1,1) → (0,n) |

> Lecture : « (1,1) → (0,n) » = chaque ligne source référence **une** cible obligatoire ; chaque cible peut être référencée par **0 à n** sources.

---

# Énumérations (valeurs de référence)

| Champ | Table | Valeurs |
|-------|-------|---------|
| role | utilisateur | super_admin, owner, comptable, membre |
| regime_tva | organisation | franchise, reel_simplifie, reel_normal |
| type | client | entreprise, particulier, public |
| plan | abonnement | gratuit, pro |
| statut | abonnement | en_essai, actif, suspendu, annule |
| statut | devis | brouillon, envoye, accepte, refuse, expire |
| type_document | facture / numerotation | facture, acompte, avoir, devis |
| statut (cycle de vie) | facture / avoir | brouillon, emise, deposee, recue, mise_a_disposition, approuvee, refusee, en_litige, encaissee, archivee, annulee |
| format | facture / transmission_pa | factur_x, ubl, cii |
| source | evenement_facture | interne, pa, webhook |
| type | plateforme_agreee | pa, chorus_pro |
| direction | transmission_pa | sortant, entrant |
| statut | transmission_pa | en_attente, depose, accepte, rejete, erreur |
| type | e_reporting | transactions, paiements |
| methode | paiement | virement, carte, cheque, especes, prelevement |
| canal | relance | email, courrier |

---

*Sereno · Dictionnaire de données · 22 entités · 2026*
