# Artefacts officiels Factur-X — XSD / Schematron

Ce répertoire accueille les artefacts de validation **officiels**, tiers, utilisés
pour vérifier la conformité structurelle et réglementaire des XML CII / Factur-X
générés par Sereno (`FacturXXmlService`).

Ces fichiers ne remplacent pas le garde-fou interne du Sprint 1A
(`backend/spec/integration/facturx_generation_spec.rb`) : ils apportent la
certification officielle que ce garde-fou interne ne peut pas fournir seul.

## Contenu attendu

### `xsd/`
Schéma(s) XSD officiels, tels que distribués dans le pack **ZUGFeRD 2.5 /
Factur-X 1.09** (FeRD), utilisés pour valider structurellement les XML CII
générés par Sereno.

`xsd/en16931/` : XSD du **profil Factur-X 1.09 EN16931** — fichier racine
`Factur-X_1.09_EN16931.xsd`, accompagné de ses 3 XSD dépendants
(`QualifiedDataType_100`, `ReusableAggregateBusinessInformationEntity_100`,
`UnqualifiedDataType_100` — tous nécessaires ensemble, imports en chemins
relatifs dans le même dossier). **Importé** (voir provenance ci-dessous).

Le pack contient également le schéma CII générique D22B
(`Schema/5. CII D22B XSD/CrossIndustryInvoice_100pD22B.xsd`), volontairement
**non importé** pour l'instant : Sereno cible le profil EN16931, pas le schéma
CII générique.

### `schematron/`
Règles **Schematron EN16931 / CIUS-FR**, selon ce que fournit le pack officiel
FNFE-MPE (validation des règles métier BR-*, au-delà de la simple structure XSD).

## Source attendue

Pack officiel **FNFE-MPE Factur-X** (Forum National de la Facture Électronique),
compatible ZUGFeRD, profil EN16931. Ne pas substituer par un schéma reconstruit
ou approximé.

## Règles d'usage

- **Ne pas modifier ces fichiers à la main.** Ce sont des artefacts tiers
  versionnés tels quels ; toute correction doit venir d'une nouvelle version du
  pack officiel, pas d'une édition locale.
- **Consigner la provenance à chaque import** : version du pack, date de
  récupération, source exacte (URL ou référence du pack). À noter dans ce
  README (section ci-dessous) ou dans un fichier `VERSION.md` à côté des
  artefacts, au moment de l'import réel.
- Tant que ces fichiers ne sont pas importés, aucune validation XSD/Schematron
  officielle n'est possible (voir Sprint 1C-A : `xmllint` absent localement,
  aucun XSD présent — STOP documenté, pas de contournement).

## Provenance du pack importé

- **Pack** : `ZF25_EN.zip`
- **Standard** : ZUGFeRD 2.5 / Factur-X 1.09
- **Profil importé** : EN16931
- **Documentation repérée dans le pack** : `Documentation/0_FACTUR-X_1.09_2026_06_10_EN.pdf`
- **Date d'import** : 2026-07-09
- **Source** : pack officiel FeRD (Forum elektronische Rechnung Deutschland)
  ZUGFeRD 2.5 / Factur-X 1.09, fourni manuellement (chemin local
  `D:/CreaSite/_facturx_officiel/ZF25_EN.zip`, hors dépôt)
- **Dossier source dans le pack** : `Schema/3_Factur-X_1.09_EN16931/`
- **Fichiers XSD importés** (dans `xsd/en16931/`) :
  - `Factur-X_1.09_EN16931.xsd` (racine)
  - `Factur-X_1.09_EN16931_urn_un_unece_uncefact_data_standard_QualifiedDataType_100.xsd`
  - `Factur-X_1.09_EN16931_urn_un_unece_uncefact_data_standard_ReusableAggregateBusinessInformationEntity_100.xsd`
  - `Factur-X_1.09_EN16931_urn_un_unece_uncefact_data_standard_UnqualifiedDataType_100.xsd`
- **Non importé à ce stade** : le Schematron `Factur-X_1.09_EN16931.sch` (présent
  dans le pack, même dossier) — import prévu au Sprint 1D dans
  `backend/vendor/facturx/schematron/en16931/`.
- **Règle** : ces fichiers sont des artefacts tiers vendored tels quels. Ne pas
  les modifier à la main — toute mise à jour doit venir d'une nouvelle version
  du pack officiel FeRD.
