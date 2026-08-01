# Socle légal gelé — Sereno

> Ce fichier définit la **frontière du socle de conformité gelé**. Il est la
> référence unique et versionnée de ce qui ne doit pas être modifié sans
> précaution. Toute session de développement (humaine ou assistée) doit le
> consulter avant de toucher au backend.
>
> **Référence de gel initiale** : tag `v0.2.0-conformite-fr` (objet annoté `0acd4d9`),
> pointant sur le commit `2079ad2` (« chore: close post-audit validation items »,
> 10 juillet 2026). Message du tag : *« Sereno v0.2.0 - Factur-X EN16931 and
> France CTC compliance validated »*.
>
> **Référence de gel COURANTE** (celle de la commande de contrôle ci-dessous) : tag
> `v0.3.0-conformite-fr`, posé le 01/08/2026 sur `main` après B4 (socle re-prouvé en
> CI à chaque commit) et la promotion de `facture_pdf_service.rb` en GELÉ STRICT. Les
> 8 chemins d'origine sont identiques entre `2079ad2` et ce tag ; le 9e chemin
> (`facture_pdf_service.rb`, modifié après `2079ad2` par le fix stockage) est gelé à
> partir de `v0.3.0-conformite-fr`.
>
> À cette date, le moteur légal complet existait déjà et était prouvé conforme
> (PDF/A-3 + CII validés). Ce fichier gèle cet état de référence.

---

## Deux niveaux de protection

Tout le code sensible n'a pas le même statut. On distingue :

- **GELÉ STRICT** — toute modification EXIGE de re-passer la validation de
  conformité (XSD, Schematron EN 16931 et PDF/A-3b via veraPDF — désormais câblés en CI depuis B4 ; France CTC / Mustang restant hors CI) ou casse une preuve déjà testée. On n'y touche pas sans re-validation
  complète et décision explicite de Sébastien.
- **SENSIBLE** — protégé par un invariant légal (immutabilité, append-only,
  numérotation sans trou). Modifiable avec rigueur et tests, mais ne déclenche
  pas d'obligation de re-passer la chaîne de validation de conformité.

---

## GELÉ STRICT

Ne jamais modifier sans re-validation de conformité et accord explicite.

- **`backend/app/services/factur_x_xml_service.rb`**
  Produit littéralement le XML CII validé par le XSD. Toute modification change
  l'artefact même qui est prouvé conforme.

- **`backend/app/services/factur_x_package_service.rb`**
  Construit l'enveloppe PDF/A-3 (OutputIntent/ICC, métadonnées XMP
  `pdfaid:conformance=B`, embarquement du XML avec AFRelationship, forçage
  PDF 1.7). C'est lui qui rend correct le round-trip PDF→XML testé aujourd'hui,
  et qui portera la conformité PDF/A-3 quand veraPDF sera câblé.

- **`backend/app/services/facture_conformite_service.rb`**
  Seul gardien des règles métier EN 16931 / France CTC (mentions BT-22,
  cohérence TVA, SIRET…) tant que le Schematron officiel n'est pas exécutable.
  Il remplace de fait cette couche de validation absente : le modifier sans
  rigueur revient à modifier la preuve elle-même.

- **`backend/app/services/facture_emission_service.rb`**
  Orchestrateur qui enchaîne conformité → numérotation → génération XML/PDF →
  assemblage → sauvegarde dans UNE transaction. Point d'entrée unique exercé par
  100 % des exemples de `facturx_generation_spec.rb` ; un simple réordonnancement
  des étapes casserait silencieusement la preuve.

- **`backend/app/services/facture_totals_service.rb`**
  Calcule totaux et groupes de TVA en `BigDecimal` avec arrondi `ROUND_HALF_UP`.
  C'est ce que vérifie le test « cohérence PDF/XML au centime (BR-CO) » ; toute
  modification de l'arrondi risque de violer une règle BR-CO déjà testée.

- **`backend/vendor/facturx/`** (répertoire entier : XSD, Schematron, README de
  provenance)
  Artefacts tiers officiels. Le README interne l'interdit explicitement
  (« Ne pas modifier ces fichiers à la main »).

- **`backend/config/facturx/sRGB.icc`**
  Profil colorimétrique utilisé tel quel dans l'OutputIntent PDF/A-3. Le
  remplacer change la preuve de conformité colorimétrique.

- **`backend/spec/integration/facturx_generation_spec.rb`**
  Modifier ce fichier reviendrait à changer la preuve elle-même plutôt qu'à la
  faire passer.

- **`backend/app/services/facture_pdf_service.rb`** — promu GELÉ STRICT le 01/08/2026
  Génère le PDF visuel de base que `FacturXPackageService` enveloppe en PDF/A-3 ;
  un PDF de base malformé casserait la conformité PDF/A. Promotion effective depuis
  que veraPDF est câblé en CI (B4 étage 2 — PDF/A-3b re-prouvé à chaque commit,
  facture ET avoir). Sa version gelée est celle du tag `v0.3.0-conformite-fr` (il
  avait été modifié après `2079ad2` par le fix stockage).

---

## SENSIBLE

Modifiable avec rigueur et tests. Ne déclenche pas de re-validation de conformité,
mais porte un invariant légal à préserver.

- **`backend/app/models/facture.rb`**
  Invariant : immutabilité des champs de contenu après émission
  (`CHAMPS_IMMUABLES_APRES_EMISSION`). Déjà modifié plusieurs fois depuis le tag
  sans incident (ex. ajout de `has_many :evenements_entrants_pa`) — ce qui
  confirme le statut « sensible » et non « gelé strict ».

- **⚠️ Colonne `factures.montant_paye` — gelée EN PRATIQUE**
  Cette colonne ne figure pas dans les 9 chemins stricts, mais elle est **lue
  par le moteur gelé** `factur_x_xml_service.rb` pour poser BT-113
  (TotalPrepaidAmount) et BT-115 (DuePayableAmount = `total_ttc − montant_paye`).
  Invariants : **ne jamais la supprimer** (la retirer casserait le moteur gelé)
  ni **la muter** (elle reste à `0` — aucun prépaiement dans le flux actuel ; le
  XML est un instantané figé à l'émission). Le suivi des paiements (v1) ne
  l'utilise pas comme cache : le « payé / reste à payer » est entièrement
  **dérivé** du journal des paiements, jamais stocké sur la facture. (Le squelette
  « paiement v0 » mort qui mutait cette colonne a été retiré à l'étage A des
  paiements v1.)

- **`backend/app/models/ligne_facture.rb`**
  Même famille d'invariant : une ligne devient immuable dès que la facture n'est
  plus en brouillon.

- **`backend/app/models/numerotation.rb`** + **`backend/app/services/numerotation_service.rb`**
  Invariant : séquence sans trou par organisation/type/année
  (`pg_advisory_xact_lock`). Exigence légale française distincte de la conformité
  structurelle EN 16931 (aucun des validateurs ne vérifie la numérotation).

- **`backend/app/models/evenement_facture.rb`**
  Invariant : append-only (`empecher_update` / `empecher_destroy`). Déjà modifié
  depuis le tag (ajout de la source `"sandbox"`) sans re-validation Factur-X.

- **`backend/app/services/factur_x_storage_service.rb`**
  Persiste un XML déjà généré ; ne génère ni n'altère de contenu légal, seulement
  son emplacement/nom. Sensible car son interface est dépendue par
  `facturx_generation_spec.rb` (lecture de `xml_url`) : un changement de
  convention de chemin casserait ce test — régression fonctionnelle, pas
  non-conformité.

---

## Explicitement LIBRES (non gelés)

Pour prouver l'absence de sur-gel, ces fichiers ont été évalués et exclus :

- **`backend/app/models/client.rb`**, **`backend/app/models/organisation.rb`** —
  portent des données injectées dans le XML (SIRET, adresse) mais restent des
  enregistrements métier modifiables ; changer l'adresse d'un client n'invalide
  pas une facture déjà émise (dont le XML/PDF est un instantané figé).
- **`backend/app/models/avoir.rb`**, **`backend/app/models/ligne_avoir.rb`** —
  jamais consommés par le moteur XML à ce jour ; totalement libres.
- **`backend/app/models/paiement.rb`**, **`backend/app/models/evenement_paiement.rb`**, et l'API des paiements (contrôleur / policy / blueprints / `PaiementService`, `PaiementSyntheseService`) — nouveau registre de suivi (paiements v1), append-only, dérivé, jamais consommé par le moteur XML ; libres.
- Tout **`backend/app/controllers/`**, **`backend/app/policies/`**,
  **`backend/app/serializers/`** liés à Facture — orchestration
  HTTP / autorisation / sérialisation, ne touchent jamais à la génération.
- **Toute la couche transmission** (`transmission_pa`, `PaStatusIngestionService`,
  `Webhooks::PaController`, etc., B1→B3.3 + R6) — consomme le résultat déjà émis,
  ne génère ni ne valide de XML/PDF Factur-X.

---

## Commande de contrôle

À lancer par tout sprint avant de rendre la main. Une sortie **vide** = socle
strict intact.

```bash
git diff --stat v0.3.0-conformite-fr..HEAD -- \
  backend/app/services/factur_x_xml_service.rb \
  backend/app/services/factur_x_package_service.rb \
  backend/app/services/facture_conformite_service.rb \
  backend/app/services/facture_emission_service.rb \
  backend/app/services/facture_totals_service.rb \
  backend/app/services/facture_pdf_service.rb \
  backend/vendor/facturx/ \
  backend/config/facturx/sRGB.icc \
  backend/spec/integration/facturx_generation_spec.rb
```

> Note : les sprints B1→R6 utilisaient une version incomplète de cette commande
> (seuls 4 des chemins gelés étaient contrôlés). Cette version complète corrige
> l'oubli — à utiliser désormais.

---

## Maintenir ce fichier honnête

- Ce fichier décrit un **état**, pas un dogme figé. Le statut de
  `facture_pdf_service.rb` évoluera (voir ci-dessus) ; d'autres pourront évoluer.
- Toute promotion « sensible → gelé strict » (ex. câblage de veraPDF) doit
  s'accompagner d'une mise à jour de ce fichier ET de la commande de contrôle.
- Ne jamais laisser ce fichier mentir : un socle mal décrit est pire qu'un socle
  non décrit.
