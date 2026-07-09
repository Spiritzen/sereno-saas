# Artefacts officiels Factur-X — XSD / Schematron

Ce répertoire accueille les artefacts de validation **officiels**, tiers, utilisés
pour vérifier la conformité structurelle et réglementaire des XML CII / Factur-X
générés par Sereno (`FacturXXmlService`).

Ces fichiers ne remplacent pas le garde-fou interne du Sprint 1A
(`backend/spec/integration/facturx_generation_spec.rb`) : ils apportent la
certification officielle que ce garde-fou interne ne peut pas fournir seul.

## Contenu attendu

### `xsd/`
Schéma(s) XSD **CII (Cross Industry Invoice)** officiel(s), tel(s) que distribué(s)
dans le pack **FNFE-MPE Factur-X** (compatible ZUGFeRD, profil EN16931).

Fichier racine attendu : `CrossIndustryInvoice_100pD22B.xsd` (ou l'équivalent de
version D22B fourni par le pack officiel), accompagné de ses XSD dépendants
(`ReusableAggregateBusinessInformationEntity`, `QualifiedDataType`,
`UnqualifiedDataType`, etc. — le schéma CII est modulaire et s'importe entre
plusieurs fichiers, tous nécessaires ensemble).

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

_Non renseigné — aucun pack officiel importé à ce jour (structure préparée par
le Sprint 1C-B, en attente d'import manuel confirmé)._
