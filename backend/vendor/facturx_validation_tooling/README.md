# Outillage de validation Schematron EN 16931 — Sereno (B4 étage 1, parties A + A-bis + B)

Ce répertoire n'est PAS gelé (absent des 8 chemins `GELÉ STRICT` de
`backend/SOCLE_GELE.md` — voir la commande de contrôle du socle, qui ignore ce
chemin). Il complète `backend/vendor/facturx/` (lui, gelé strict) sans jamais y
écrire ni le modifier : le `.sch` officiel s'y trouve toujours, en lecture
seule, inchangé.

## Pourquoi ce répertoire existe

Le Schematron officiel EN 16931 (`vendor/facturx/schematron/en16931/Factur-X_1.09_EN16931.sch`,
gelé) référence une ressource externe unique, `Factur-X_1.09_EN16931_codedb.xml`,
via 59 appels `document('Factur-X_1.09_EN16931_codedb.xml')` (listes de codes :
devises, pays, unités, catégories de TVA, etc., consolidées dans un seul
fichier). Ce fichier fait partie du même pack officiel que le `.sch` et les XSD
déjà vendorés, mais n'avait pas été importé à l'époque (seuls XSD + Schematron
l'avaient été). Sans lui, le Schematron ne peut pas s'exécuter jusqu'au bout
(erreur `Can not resolve required Factur-X_1.09_EN16931_codedb.xml`).

## Contenu

### `schematron_en16931/Factur-X_1.09_EN16931_codedb.xml`

**Vendoré tel quel**, artefact tiers officiel — même règle que
`vendor/facturx/` : ne pas modifier à la main.

- **Pack** : `ZF25_EN.zip` (identique à celui déjà documenté dans
  `vendor/facturx/README.md`)
- **Standard** : ZUGFeRD 2.5 / Factur-X 1.09, profil EN16931
- **Dossier source dans le pack** : `Schema/3_Factur-X_1.09_EN16931/` (le MÊME
  dossier que le `.sch`/XSD déjà vendorés — ce fichier est un sibling direct
  dans le pack d'origine, jamais importé jusqu'ici)
- **Source** : pack officiel FeRD, retrouvé à son emplacement local d'origine
  documenté dans `vendor/facturx/README.md` (`D:/CreaSite/_facturx_officiel/ZF25_EN.zip`,
  hors dépôt), extrait sous `D:/CreaSite/_facturx_officiel/extracted/Schema/3_Factur-X_1.09_EN16931/`
- **Date de récupération** : 2026-07-29
- **Intégrité** : copie vérifiée octet-pour-octet identique au fichier du pack
  officiel extrait (`diff` sans écart)
- **Licence** : celle du pack FeRD (voir `vendor/facturx/README.md` — pas de
  licence distincte reproduite ici, comme pour le `.sch`/XSD déjà vendorés)

### `schematron_en16931/Factur-X_1.09_EN16931-compiled.xsl`

**PAS un artefact tiers** — un artefact **dérivé, reproductible**, compilé par
Sereno à partir du `.sch` gelé (lu, jamais modifié), via :

1. [Saxon-HE 13.0](https://repo1.maven.org/maven2/net/sf/saxon/Saxon-HE/13.0/)
   (Mozilla Public License 2.0) + sa dépendance `org.xmlresolver:xmlresolver:6.0.23`
   (requise depuis Saxon 13)
2. Le squelette officiel ISO Schematron pour XSLT2/Saxon
   (`iso_svrl_for_xslt2.xsl` + `iso_schematron_skeleton_for_saxon.xsl`, dépôt
   [`Schematron/schematron`](https://github.com/Schematron/schematron),
   Apache License 2.0 / MIT selon les fichiers du dépôt), **avec un patch
   Sereno minimal** (voir « Patch @id » ci-dessous)

**Recompilation (B4 étage 1, partie B)** : `bundle exec rails conformite:compiler_schematron`
— outil DEV, **jamais invoqué par le gate `conformite:valider` ni par la CI**
(qui consomment le XSLT déjà committé). Cette tâche travaille sur une COPIE
temporaire du `.sch` gelé (jamais l'original) et régénère
`Factur-X_1.09_EN16931-compiled.xsl` à partir du squelette patché ci-dessous.
Elle nécessite Saxon-HE 13.0 + `xmlresolver` 6.0.23 (JAR non vendorés — à
télécharger, chemins configurables via `SAXON_JAR_PATH`/`XMLRESOLVER_JAR_PATH`,
par défaut `backend/tmp/conformite_tools/`) :
- Saxon-HE 13.0 : `https://repo1.maven.org/maven2/net/sf/saxon/Saxon-HE/13.0/Saxon-HE-13.0.jar`
- xmlresolver 6.0.23 : `https://repo1.maven.org/maven2/org/xmlresolver/xmlresolver/6.0.23/xmlresolver-6.0.23.jar`

À ne relancer que si le squelette lui-même évolue (le `.sch` gelé, lui, ne
changera jamais). Après recompilation, relire le diff produit et relancer
`bundle exec rails conformite:valider` avant tout commit.

Ce fichier compilé n'est PAS à modifier à la main non plus (c'est un artefact
généré), mais pour une raison différente du `.sch`/XSD/`codedb.xml` : le
régénérer est sans risque et reproductible, l'éditer à la main ne le serait pas.

#### Patch `@id` (B4 étage 1, partie A-bis)

Le squelette ISO standard n'émet l'attribut `@id` sur `<svrl:failed-assert>`/
`<svrl:successful-report>` QUE si l'`<assert>`/`<report>` **source** en porte
un. Le `.sch` officiel FeRD n'en porte aucun (0 sur 618 vérifié), ce qui est
parfaitement valide au sens ISO Schematron/SVRL (l'`id` y est optionnel) —
mais le schéma de rapport **interne** de Mustang (`svrl-kosit.xsd`, embarqué
dans son JAR) le rend **obligatoire** (`use="required"`) sur ces deux
éléments. Sans lui, Mustang classait tout document (même parfaitement
conforme) en `UNDEFINED` au lieu d'`ACCEPTABLE`, à cause d'une erreur de
validation de SON PROPRE rapport (`cvc-complex-type.4`), pas d'un échec de
règle métier.

Fix retenu : une copie patchée du squelette, rangée (B4 étage 1, partie B)
dans `schematron_en16931/skeleton/` :
- `skeleton/iso_svrl_for_xslt2.xsl` — squelette ISO **original, non modifié**
  (conservé pour montrer le diff exact du patch) ;
- `skeleton/iso_svrl_for_xslt2_sereno_id_fix.xsl` — la copie **patchée**,
  réellement utilisée pour compiler `Factur-X_1.09_EN16931-compiled.xsl` ;
- `skeleton/iso_schematron_skeleton_for_saxon.xsl` — dépendance importée par
  les deux ci-dessus (non modifiée), nécessaire à la compilation.

Dans les deux templates concernés (`process-assert`, `process-report`),
l'émission de `@id` devient **toujours** inconditionnelle — celui de la
source s'il existe, sinon `generate-id(.)` évalué à l'exécution sur le nœud
du document instance en cours de validation. Aucune logique de test/assert
n'est modifiée ; seul un attribut de libellé de rapport, absent de la source
et non porteur de sens métier, est synthétisé. Preuve que rien n'est masqué :
un XML délibérément corrompu (code devise invalide) est toujours classé
`REJECTED` avec les `failed-assert` attendus après ce patch (voir rapport
technique du sprint).

### `scenarios.xml`

Scénario [KoSIT Validator (« Mustang »)](https://github.com/itplr-kosit/validator)
1.6.2, **écrit par Sereno** — aucun scénario Factur-X public n'existe (le
projet Mustang ne publie que des scénarios XRechnung/Peppol BIS/XGewerbeanzeige).
Conforme au schéma officiel `scenarios.xsd` du validateur. Référence :
- le XSD EN16931 gelé, lu en place dans `vendor/facturx/xsd/en16931/` (jamais copié) ;
- le Schematron compilé ci-dessus (`schematron_en16931/Factur-X_1.09_EN16931-compiled.xsl`,
  qui résout `codedb.xml` par URI relative bare — d'où sa présence dans le
  MÊME dossier que le fichier compilé, exactement comme dans le pack officiel
  d'origine où `.sch` et `codedb.xml` sont déjà côte à côte).

Le scénario s'utilise avec `-r backend/` (racine du dépôt backend, ancêtre
commun du XSD gelé et de ce dossier non gelé) et
`-s backend/vendor/facturx_validation_tooling/scenarios.xml`.

## Gate CI (B4 étage 1, partie B)

`bundle exec rails conformite:valider` (`backend/lib/tasks/conformite.rake`) :
émet une facture (380) et un avoir (381) dessus, en TVA standard ET en
franchise en base de TVA (art. 293 B du CGI), chacun dans une transaction
PostgreSQL explicitement annulée (rien n'est persisté), les valide via ce
scénario, et exige `ACCEPTABLE` + 0 `failed-assert` sur les 4. Inclut un
auto-test négatif permanent (un artefact corrompu doit rester `REJECTED`) :
sans lui, une régression du validateur lui-même passerait inaperçue. Exit
non-zéro dès qu'un artefact échoue, qu'une erreur d'infrastructure survient
(JAR/JRE introuvable), ou que le négatif n'est plus rejeté.

Lancé en CI par le job `conformite` de `.github/workflows/ci.yml`, qui
télécharge Mustang (version épinglée, `MUSTANG_VERSION`) et le met en cache.
**Ce job couvre 2 des 4 niveaux de conformité Factur-X** (structure XSD +
règles métier Schematron EN 16931) — ni veraPDF (PDF/A-3b, étage 2 à venir)
ni les règles France CTC/BR-FR (aucun scénario Mustang officiel n'existe à
ce jour) ne sont couverts. Ne pas présenter ce job comme une preuve de
conformité complète.
