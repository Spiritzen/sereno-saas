# Dettes connues — Sereno

> Fichier vivant. Source initiale : audit delta du 22/07/2026 (97,5/100, GREEN),
> re-constaté depuis le code. Mis à jour le 28/07/2026 après B5 (chiffrement),
> B3.2 (supervision), B3.3 (webhook), R6 (rate limiting), V1.2a-d (avoirs),
> le fix stockage (cloisonnement par environnement), et l'AUDIT COMPLET du
> 28/07/2026 (99/100, GREEN — a réconcilié 2 dettes mineures : n°21 et n°22).
> Mis à jour le 30/07/2026 après **B4 étages 1 & 2** (preuve de conformité en CI :
> XSD + Schematron EN 16931 via Mustang, puis PDF/A-3b via veraPDF, re-jouées à
> chaque push sur facture ET avoir, en TVA standard ET en franchise, avec
> auto-tests négatifs permanents). A résolu la n°10 (pour son périmètre), mitigé
> la n°14, et ajouté les n°23 à n°25.
> Mis à jour le 01/08/2026 après **paiements v1** (suivi local « payé / reste à
> payer », registre append-only, moyens UNTDID 4461, synthèse dérivée) : ajout des
> n°26 à n°29. Découverte au passage : « Encaissée » est un statut SORTANT que le
> vendeur déclare (v2 e-reporting), pas une notification reçue — d'où la séparation
> stricte entre le règlement local et le statut PA « encaissée ».
> Mis à jour le 13/08/2026 après **Relances v1a (bouton manuel)**, **v1b (planificateur
> automatique)** et **Portail destinataire MVP (lien de partage tokenisé, lecture seule)** :
> ajout des n°30 à n°35 — dont la règle de méthode « ne jamais éditer schema.rb à la main »
> (issue d'un incident v1b) et le cadrage du futur **espace client authentifié**
> multi-fournisseurs (distinct du portail MVP). Les dettes de conception des relances v1a
> figurent aussi dans le bloc daté dédié ci-dessous.
> Mis à jour le 15/08/2026 après le fast-follow **lien du portail dans la relance**
> (RelanceService génère désormais paresseusement un lien de partage à chaque envoi,
> manuel ET auto — point d'injection unique, plusieurs liens actifs autorisés) : ajout
> des n°36 et n°37.
> Socle : v0.3.0-conformite-fr. Frontière du socle : voir backend/SOCLE_GELE.md.

- **Légende sévérité** : HAUTE > MOYENNE > BASSE > INFO > MINEURE
- **Légende statut** : NON RÉSOLUE · RÉSOLUE

## Dettes non résolues

### Dette n°21 — policies emettre?/update?/destroy? gardent sur l'état du document (403 au lieu de 422)
- **Sévérité** : MINEURE
- **Statut** : NON RÉSOLUE (découverte à l'audit du 28/07 ; pré-existante depuis V1.1)
- **Preuve** : certaines policies Pundit (facture et avoir : `emettre?`, `update?`, `destroy?`) vérifient l'ÉTAT du document (ex. « la facture est-elle en brouillon ? ») en plus du rôle+tenant. Une action sur un document dans le mauvais état renvoie donc un **403 (refus d'accès)** au lieu d'un **422 (règle métier)**. Cela contrevient légèrement à la règle du projet « policy = rôle+tenant uniquement ; éligibilité métier = modèle/service → 422 ». L'immutabilité reste garantie par ailleurs (le modèle bloque aussi indépendamment), donc aucune faille — juste un code HTTP moins juste sémantiquement.
- **Impact / pourquoi c'est une dette** : purement sémantique/cosmétique côté API. Un client de l'API reçoit un 403 (« tu n'as pas le droit ») là où un 422 (« l'état ne le permet pas ») serait plus exact. Aucun impact fonctionnel ni de sécurité : l'action reste correctement bloquée, et à deux niveaux (policy + modèle).
- **Quand la traiter** : au prochain passage sur les policies facture/avoir, si l'uniformisation devient prioritaire. Alternative : ASSUMER cette entorse comme un choix durable (le double blocage est même une ceinture de sécurité). Décision de Sébastien : uniformiser (403→422) ou acter le choix.

### Dette n°22 — pas de test permanent de chiffrement pour webhook_secret_chiffre
- **Sévérité** : MINEURE
- **Statut** : NON RÉSOLUE (découverte à l'audit du 28/07)
- **Preuve** : `credentials_chiffres` a un test permanent qui prouve le chiffrement au repos (lecture SQL brute ≠ clair, dans `plateforme_agreee_spec.rb`). Mais `webhook_secret_chiffre` (chiffré par le même mécanisme `encrypts`) n'a PAS d'équivalent dans la suite. L'audit du 28/07 a vérifié à neuf que le chiffrement fonctionne bien (lecture SQL brute dans une transaction annulée), mais ce n'est pas un test PERMANENT.
- **Impact / pourquoi c'est une dette** : aucun aujourd'hui — le mécanisme `encrypts` est identique pour les deux colonnes, la garantie tient (vérifiée à l'audit). MAIS une régression future (ex. retrait accidentel de `encrypts :webhook_secret_chiffre`) ne serait PAS détectée par la suite actuelle. C'est un trou de filet de sécurité, pas un bug.
- **Quand la traiter** : coût trivial — ajouter 1-2 exemples à `plateforme_agreee_spec.rb` sur le modèle EXACT des tests `credentials_chiffres`. À faire au prochain sprint backend touchant ce fichier (ou tout de suite, c'est 10 minutes).

### Dette n°23 — matrice d'échantillons de conformité limitée (gate CI)
- **Sévérité** : BASSE
- **Statut** : NON RÉSOLUE (découverte à B4 étage 1)
- **Preuve** : le gate CI (`conformite:valider` dans `backend/lib/tasks/conformite.rake`) n'émet et ne valide que **2 scénarios** : TVA standard et franchise en base de TVA (art. 293 B), chacun en facture (380) ET avoir (381). Les profils EN 16931 réels non échantillonnés : client étranger (devise/pays hors zone), multi-taux sur une même facture, autoliquidation, acomptes, remises.
- **Impact / pourquoi c'est une dette** : le gate ne protège que ce qu'il génère. Une régression de conformité spécifique à un profil non échantillonné (ex. une règle Schematron liée à un taux inter-communautaire) ne serait pas détectée en CI. Aucun impact aujourd'hui (ces profils ne sont pas encore émis en prod), mais la couverture est à élargir avec le produit.
- **Quand la traiter** : au fil des besoins, en ajoutant des cas à la génération de paires dans `conformite.rake` (chaque nouveau profil émis en prod devrait être échantillonné par le gate).

### Dette n°24 — France CTC / BR-FR non automatisable en CI (aucun scénario public)
- **Sévérité** : BASSE
- **Statut** : NON RÉSOLUE (blocage externe, pas un défaut d'outillage Sereno)
- **Preuve** : le validateur Mustang / KoSIT ne publie **aucun scénario Factur-X / France CTC** (il ne fournit officiellement que XRechnung, Peppol BIS, XGewerbeanzeige — vérifié au spike B4 étage 0). Le niveau « BR-FR / Flux 2 » ne peut donc pas être câblé en CI comme les trois autres. Les mentions France CTC (BT-30/34/49, notes PMT/PMD/AAB, ProfileID) sont bien **implémentées** dans le code ; leur validation Mustang BR-FR a été effectuée **manuellement au gel du socle**, non rejouable aujourd'hui faute de scénario public.
- **Impact / pourquoi c'est une dette** : c'est le 4ᵉ niveau de conformité, le seul qui reste hors CI. Ce n'est pas une limite technique de l'outillage mis en place (Mustang tourne), c'est l'absence d'un référentiel officiel exécutable pour ce profil. Une régression sur une mention France CTC ne serait pas attrapée automatiquement.
- **Quand la traiter** : à réévaluer si un scénario Mustang France CTC officiel apparaît. À défaut, envisager de coder nous-mêmes quelques règles BR-FR critiques en Schematron custom (chantier séparé, à décider) — sinon la valider manuellement à chaque évolution du moteur de mentions.

### Dette n°25 — frontend non vérifié en CI (eslint / tsc / build)
- **Sévérité** : MOYENNE
- **Statut** : NON RÉSOLUE (découverte à la reconnaissance B4)
- **Preuve** : `.github/workflows/ci.yml` ne contient **aucun job frontend** : les jobs sont `scan_ruby` (bundler-audit), `lint` (RuboCop, backend), `test` (RSpec, backend) et `conformite` (gate EN 16931 + PDF/A-3b). `npm run lint` / `tsc -b` / `npm run build` ne tournent **que sur le poste du développeur**, jamais sur une PR. Combinée à la dette n°9 (pas de Vitest), le frontend n'a donc **aucun filet automatique en CI**.
- **Impact / pourquoi c'est une dette** : une régression frontend (erreur eslint, type cassé, build rompu) ne serait pas attrapée par la CI et pourrait être mergée. Le risque est atténué pour un développeur solo qui lance ces contrôles en local avant de commiter, mais l'absence d'enforcement reste un trou de filet.
- **Quand la traiter** : ajouter un job `frontend` à `ci.yml` (`npm ci` + `npm run lint` + `tsc -b` + `npm run build`), calqué sur les jobs existants. Coût faible, forte valeur — bon candidat pour un petit sprint utilitaire.

### Dette n°26 — pas d'endpoint de suppression d'un paiement brouillon résiduel
- **Sévérité** : BASSE
- **Statut** : NON RÉSOLUE (découverte à l'étage C des paiements v1)
- **Preuve** : le frontend crée un paiement (brouillon) puis le confirme en une action (`handleRegisterPaiement` → `createPaiement` puis `confirmerPaiement`). Si `confirmer` échoue après un `create` réussi (ex. coupure réseau), un paiement en statut `brouillon` orphelin reste en base, sans moyen de le supprimer : aucune action `discard`/`destroy` n'existe (le `PaiementsController` n'expose que create/confirmer/annuler/index). L'utilisateur voit un bouton « Confirmer » pour réessayer, mais ne peut pas jeter le brouillon.
- **Impact / pourquoi c'est une dette** : mineur — un brouillon orphelin ne compte PAS dans le reste à payer (seuls les paiements confirmés comptent), donc aucun impact sur les montants. Simple résidu de données dans un cas d'erreur rare.
- **Quand la traiter** : ajouter une action `destroy` (ou `discard`) au `PaiementsController`, limitée aux paiements en statut brouillon (jamais un confirmé), avec sa policy et son test. Ajout backend mineur.

### Dette n°27 — énumération des moyens de paiement dupliquée front↔back (drift possible)
- **Sévérité** : BASSE
- **Statut** : NON RÉSOLUE (découverte à l'étage C des paiements v1)
- **Preuve** : la liste des moyens UNTDID 4461 existe en DEUX endroits maintenus en miroir manuellement : `Paiement::MOYENS` (backend) et la constante `MOYENS_PAIEMENT` (frontend, pour le menu déroulant). Aucun endpoint ne les synchronise. Si un moyen est ajouté/modifié d'un côté sans l'autre → désalignement silencieux (un code accepté par l'API mais absent du menu, ou l'inverse).
- **Impact / pourquoi c'est une dette** : aucun aujourd'hui (5 moyens stables). Deviendrait un risque le jour où on ajoute un moyen (cf. dette n°29).
- **Quand la traiter** : le jour d'un ajout de moyen — exposer les moyens via un petit endpoint d'énumération que le front consomme (source unique de vérité), ou générer la constante front depuis le back. À coupler avec la n°29.

### Dette n°28 — e-reporting d'encaissement non construit (paiements v2)
- **Sévérité** : BASSE
- **Statut** : NON RÉSOLUE (choix de périmètre assumé — v1 = suivi seul)
- **Preuve** : la v1 assure le suivi LOCAL (payé / reste à payer, statut d'encaissement local dérivé) mais ne DÉCLARE rien à l'administration. Or le statut « Encaissée » (obligatoire pour les prestations de services, TVA sur les encaissements) est un statut SORTANT que le vendeur déclare au PPF (recherche confirmée le 01/08/2026). Sereno ne le génère ni ne le transmet encore. Voir le rapport de cadrage « Paiements V2 ».
- **Impact / pourquoi c'est une dette** : aucun avant l'entrée en vigueur de l'obligation (septembre 2026, phasage). Le modèle v1 est conçu pour ne pas la bloquer (date d'encaissement, montant, moyen 4461, ventilation TVA reconstituable captés). ⚠️ À corriger en v2 : le sandbox de transmission simule aujourd'hui « encaissee » comme un statut ENTRANT, alors que pour le vendeur c'est SORTANT.
- **Quand la traiter** : brique dédiée v2, après re-sourçage du format e-reporting en vigueur (les specs évoluent).

### Dette n°29 — moyens de paiement limités aux courants (UNTDID 4461)
- **Sévérité** : BASSE
- **Statut** : NON RÉSOLUE (choix assumé)
- **Preuve** : la v1 ne gère que 5 moyens courants (espèces 10, chèque 20, carte 48, virement SEPA 58, prélèvement SEPA 59), alignés sur UNTDID 4461. D'autres moyens (PayPal, Stripe, virement hors-SEPA, etc.) ne sont pas gérés. Le code 58 (virement SEPA) est utilisé pour « virement » : un virement hors-SEPA serait mal étiqueté (limite assumée, cible SEPA).
- **Impact / pourquoi c'est une dette** : aucun pour la cible TPE/micro/freelance (le virement SEPA domine). Coût d'ajout faible.
- **Quand la traiter** : à l'apparition d'un besoin réel — ajouter une valeur à l'énumération (à coupler avec la n°27 pour éviter le drift front↔back).

### Dette n°2 — index unique 1 PA par organisation
- **Sévérité** : MOYENNE
- **Statut** : NON RÉSOLUE
- **Preuve** : `backend/db/schema.rb:403` → `t.index ["organisation_id"], name: "index_plateformes_agreees_on_organisation_id", unique: true`. Une organisation ne peut avoir qu'une seule `PlateformeAgreee` en base.
- **Impact / pourquoi c'est une dette** : empêche structurellement une organisation d'avoir simultanément une Plateforme Agréée (PA) ET Chorus Pro connectés.
- **Quand la traiter** : avant V1.4 (introduction de Chorus Pro) si la coexistence des deux canaux devient un besoin réel.

### Dette n°3 — occurred_at absent, fallback sur received_at
- **Sévérité** : MOYENNE
- **Statut** : NON RÉSOLUE
- **Preuve** : `backend/app/services/pa_status_ingestion_service.rb:149` → `occurred_at_effectif = status_result.occurred_at || received_at`. Le fallback est documenté en commentaire dans `facture_status_transition_policy.rb:99-101` (garde temporelle basée sur `occurred_at`, avec le risque explicité si absent).
- **Impact / pourquoi c'est une dette** : si un provider n'envoie jamais d'horodatage fiable, la garde temporelle retombe sur l'heure de réception côté Sereno, qui ne protège pas totalement contre un désordre réseau (message reçu en retard mais traité comme s'il venait d'arriver).
- **Quand la traiter** : avant le branchement d'une vraie PA, en confirmant que le provider réel fournit bien un `occurred_at`.

### Dette n°9 — aucun test frontend (Vitest)
- **Sévérité** : MOYENNE
- **Statut** : NON RÉSOLUE
- **Preuve** : `grep -n "vitest" frontend/package.json` → aucun résultat. `ls frontend | grep -i vitest` → aucun résultat. Le frontend n'a que `eslint` et `tsc -b` comme filets — exécutés **en local par le développeur**, PAS en CI (cf. dette n°25) —, aucun test de comportement.
- **Impact / pourquoi c'est une dette** : les composants React (dont `InvoiceTransmissionSection`, `ModalShell`, `InvoiceLifecycleTimeline`) ne sont vérifiés que par lecture de code et build, jamais par un test automatisé de comportement. Concerne en particulier les 3 comportements UX de B3.2 (badge persistant, bouton relance conditionnel, message 422) et le sticky compact.
- **Quand la traiter** : V1.2.

### Dette n°5 — polling d'une facture devenue terminale par un autre chemin
- **Sévérité** : MINEURE (bornée)
- **Statut** : NON RÉSOLUE (désormais TRAITABLE — voir « Quand la traiter »)
- **Preuve** : `backend/app/jobs/pa_poll_transmission_job.rb:75` (`stopper_si_condition_arret!`) et le commentaire associé (lignes 42-74) documentent l'écart argumenté. Si une facture devient terminale par un autre chemin que ce job (ex. le bouton manuel B3.1a, ou désormais le webhook B3.3), le job continue à la sonder au backoff normal jusqu'à ce que la LIMITE TEMPORELLE (§7 du job, `transmis_at + 90j` ou `date_echeance + 30j`) le stoppe. Testé explicitement : `backend/spec/jobs/pa_poll_transmission_job_spec.rb`, `describe "7. LIMITE TEMPORELLE"` (3 exemples) et `describe "8. requires_review NE BLOQUE PAS le polling"`.
- **Impact / pourquoi c'est une dette** : sondages automatiques inutiles (mais bornés dans le temps, jamais infinis) sur une facture déjà réglée par un autre canal.
- **Quand la traiter** : maintenant POSSIBLE, plus seulement planifié. Le webhook B3.3 est en place : il devient la porte légitime pour recevoir un statut tardif (dont `requires_review`), ce qui autorise à resserrer le polling pour qu'il s'arrête net sur statut terminal. La porte est ouverte, pas encore empruntée — le resserrement reste à implémenter dans une tranche dédiée.

### Dette n°11 — source d'ingestion non distinguée par porte d'entrée
- **Sévérité** : BASSE
- **Statut** : NON RÉSOLUE
- **Preuve** : `backend/app/services/pa_status_ingestion_service.rb` — le code de persistance partagé (`traiter_nouvelle_notification!`) écrit `EvenementFacture.source` avec la valeur `"sandbox"` quelle que soit la porte d'entrée. Depuis B3.3, une notification reçue par webhook réutilise ce même code (couloir unique via `#ingest`) et hérite donc de `source: "sandbox"`, sans distinction `"webhook"` / `"polling"` / `"bouton"`.
- **Impact / pourquoi c'est une dette** : le journal ne dit pas PAR QUELLE porte une information est entrée. Aucun impact fonctionnel aujourd'hui (tout est sandbox), mais touche la traçabilité au sens de la règle d'honnêteté produit dès qu'une vraie PA notifiera par des canaux distincts. Choix assumé en B3.3 : ne pas modifier `traiter_nouvelle_notification!` pour préserver la réutilisation « telle quelle » du couloir unique.
- **Quand la traiter** : au branchement d'une vraie PA, quand distinguer webhook / polling / synchro manuelle deviendra un besoin réel de traçabilité.

### Dette n°20 — résidu de scratch dans storage/test/ (fichier gelé)
- **Sévérité** : INFO
- **Statut** : NON RÉSOLUE (par choix — le fichier concerné est gelé)
- **Preuve** : depuis le cloisonnement du stockage par environnement (fix stockage), les fichiers de test sont écrits sous `storage/test/factures/<id>/`. Mais `spec/integration/facturx_generation_spec.rb` (GELÉ STRICT) contient un nettoyage `rm_rf` pointant l'ancien chemin non namespacé (`storage/factures/<id>/`) — il ne correspond donc plus à l'emplacement réel d'écriture. Conséquence : quelques dossiers de scratch s'accumulent sous `storage/test/factures/` à chaque exécution de ce fichier gelé.
- **Impact / pourquoi c'est une dette** : strictement inoffensif — uniquement dans `storage/test/` (jamais `storage/development/`, jamais versionné, jamais en prod), aucun impact sur les tests (les lectures passent par `pdf_url`/`xml_url` qui restent corrects). Le corriger imposerait de modifier `facturx_generation_spec.rb`, qui est gelé strict — donc on n'y touche pas.
- **Quand la traiter** : optionnel. Une purge globale de `storage/test/` avant chaque suite (dans un hook de `rails_helper.rb`, fichier LIBRE) serait désormais totalement sûre grâce au cloisonnement par environnement — sans jamais toucher au fichier gelé. À faire si l'accumulation gêne.

### Dette n°18 — relance de polling non étendue à l'avoir
- **Sévérité** : BASSE
- **Statut** : NON RÉSOLUE
- **Preuve** : `PaPollingRelanceService` et l'endpoint `relancer` (livrés en B3.2 pour relancer un polling en pause) restent câblés sur les factures. V1.2c a généralisé la transmission/ingestion de l'avoir (couloir agnostique via `document`) mais n'a pas étendu la relance de polling à l'avoir (hors périmètre explicite du sprint).
- **Impact / pourquoi c'est une dette** : un polling de transmission d'avoir mis en pause ne peut pas être relancé manuellement comme celui d'une facture. Impact limité (le polling reprend de lui-même selon son backoff ; la relance est un confort de supervision), et l'avoir se transmet et s'ingère correctement par ailleurs.
- **Quand la traiter** : si le besoin de superviser finement la transmission des avoirs émerge, généraliser `PaPollingRelanceService`/`relancer` à l'avoir sur le modèle de ce qui a été fait pour la transmission (via `document`).

### Dette n°19 — PaRetryStuckSubmissionJob reste facture-only
- **Sévérité** : BASSE
- **Statut** : NON RÉSOLUE
- **Preuve** : `PaRetryStuckSubmissionJob` (retry des soumissions PA bloquées) n'a pas été généralisé à l'avoir en V1.2c (hors périmètre explicite). Il ne cible que les transmissions liées à une facture.
- **Impact / pourquoi c'est une dette** : une transmission d'avoir restée bloquée en cours de dépôt ne bénéficie pas du mécanisme de retry automatique dont bénéficient les factures. Impact faible en sandbox (pas de vraie PA qui bloque) ; à traiter avant le branchement d'une vraie PA si le retry doit couvrir les avoirs.
- **Quand la traiter** : au branchement d'une vraie PA, en généralisant le job à `document` comme le reste de la couche transmission.

### Dette n°7 — bruit ::text dans schema.rb
- **Sévérité** : INFO
- **Statut** : NON RÉSOLUE
- **Preuve** : `grep -n "::text" backend/db/schema.rb` → une trentaine d'occurrences, toutes dans des `check_constraint` (cast PostgreSQL généré automatiquement par la version locale de PG lors du dump). Le fichier est committé proprement tel quel.
- **Impact / pourquoi c'est une dette** : artefact cosmétique de la version PostgreSQL locale utilisée pour générer le schema. Risque théorique de divergence si la CI utilise une version de PG différente et régénère le schema autrement.
- **Quand la traiter** : pas d'action requise, surveiller en CI si un diff de schema apparaît un jour de façon inattendue.

### Dette n°12 — statut HTTP :unprocessable_entity déprécié
- **Sévérité** : INFO
- **Statut** : NON RÉSOLUE
- **Preuve** : à l'exécution de `bundle exec rspec`, avertissement récurrent : `Status code :unprocessable_entity is deprecated and will be removed in a future version of Rack. Please use :unprocessable_content instead.` (émis par `rspec-rails`/Rack). Le symbole `:unprocessable_entity` (422) reste fonctionnel mais est déprécié.
- **Impact / pourquoi c'est une dette** : purement anticipatoire. Le code fonctionne aujourd'hui ; il faudra remplacer `:unprocessable_entity` par `:unprocessable_content` avant que Rack ne retire l'ancien symbole dans une version future, sous peine de casse à ce moment-là.
- **Quand la traiter** : lors d'une prochaine montée de version des gems (Rack/Rails), remplacer les occurrences de `:unprocessable_entity` par `:unprocessable_content`.

### Dette n°14 — AvoirXmlService duplique le CII de FacturXXmlService (voie b)
- **Sévérité** : INFO (dette de conception assumée)
- **Statut** : NON RÉSOLUE (par choix — voir « Quand la traiter »)
- **Preuve** : `backend/app/services/avoir_xml_service.rb` est un service neuf, dupliqué-adapté de `factur_x_xml_service.rb` (gelé strict, cf. `backend/SOCLE_GELE.md`), avec `DOCUMENT_TYPE_CODE = "381"` et le bloc BT-25. La duplication était le choix acté (voie b) pour ne jamais rouvrir le moteur légal gelé.
- **Impact / pourquoi c'est une dette** : toute évolution future des règles EN 16931 / France CTC sur le CII du 380 (ordre des éléments, mentions BT-22, nouvelles règles BR) devra être répercutée MANUELLEMENT dans `AvoirXmlService` pour le 381. Un oubli créerait une divergence silencieuse entre facture et avoir.
- **Mitigation (B4, 30/07)** : le risque de divergence silencieuse est désormais **gardé en continu** pour les règles EN 16931 génériques — le gate CI valide le 381 au Schematron à chaque push, exactement comme le 380 (vérifié à B4 étage 1 : zéro divergence sur le code actuel). Ne subsiste hors garde que la dimension **France CTC** (BR-FR), non automatisable en CI faute de scénario public (cf. dette n°24).
- **Quand la traiter** : c'est une dette ASSUMÉE, pas à « résoudre ». Le gel du socle prime sur la non-duplication. À garder en tête à chaque évolution du moteur XML facture : mettre à jour les deux services en miroir.

### Dette n°15 — AvoirPdfService duplique la mise en page de FacturePdfService (voie b)
- **Sévérité** : INFO (dette de conception assumée)
- **Statut** : NON RÉSOLUE (par choix)
- **Preuve** : `backend/app/services/avoir_pdf_service.rb` est neuf, dupliqué de `facture_pdf_service.rb` (sensible), avec une structure simplifiée (pas de section échéance/paiement — un avoir crédite, il ne réclame pas de paiement). La duplication a été préférée à forcer le modèle Avoir à porter des champs Facture (`date_echeance`, `montant_paye`) qui n'ont pas de sens pour une note de crédit.
- **Impact / pourquoi c'est une dette** : la mise en page PDF de l'avoir devra être synchronisée manuellement si celle de la facture évolue.
- **Quand la traiter** : dette assumée, même logique que la n°14.

### Dette n°16 — type total/partiel des avoirs non modélisé
- **Sévérité** : INFO (note de conception)
- **Statut** : NON RÉSOLUE (choix durable acté par Sébastien)
- **Preuve** : la table `avoirs` n'a pas de colonne `type` (total/partiel). Décision de V1.2a : rien dans le XML (381 + BT-25 + lignes) ni dans la conformité n'a besoin de cette distinction. Le seul invariant qui compte — somme des avoirs émis sur une facture ≤ TTC de la facture — est vérifié sans étiquette (`AvoirConformiteService`), et fonctionne identiquement pour un avoir « total » (toutes les lignes) ou « partiel » (certaines lignes).
- **Impact / pourquoi c'est une dette** : aucune conséquence au niveau émission/XML/conformité — le noyau supporte déjà le partiel sans le savoir. La distinction n'a de sens que côté UX (quelles lignes pré-remplir à la création d'un avoir).
- **Quand la traiter** : choix durable confirmé. À réévaluer UNIQUEMENT si l'API (V1.2b) ou le frontend (V1.2d) a besoin d'exposer explicitement la distinction total/partiel à l'utilisateur — auquel cas ce serait probablement une donnée DÉRIVÉE (l'avoir reprend-il toutes les lignes ?) plutôt qu'une colonne à maintenir.

### Dette n°6 — worker Solid Queue inopérant sous Windows (SIGQUIT)
- **Sévérité** : INFO (dette d'environnement de dev)
- **Statut** : NON RÉSOLUE
- **Preuve** : comportement connu de la gem Solid Queue, qui tente de piéger `SIGQUIT` — non supporté nativement par Windows/MinGW. Le polling automatique est prouvé fonctionnellement par la suite de tests (`pa_polling_scanner_job_spec.rb`, `pa_poll_transmission_job_spec.rb`, verts), qui ne dépendent pas du worker réel. Contournement en dev : Docker, WSL2, ou déclenchement manuel en console.
- **Impact / pourquoi c'est une dette** : aucun sur le produit — la production tourne sous Linux. Gêne uniquement le développement local sous Windows natif.
- **Quand la traiter** : jamais (dette d'environnement, pas de dette produit).

### Dettes — Relances v1a (exécution du 12/08/2026)

  - Dette — « relance » surchargé : le terme désigne désormais deux choses
    distinctes — la relance CLIENT (dunning : RelanceService / RelanceMailer) et
    la relance du POLLING PA (FacturePolicy#relancer?). À nommer explicitement à
    l'avenir pour éviter toute confusion.

  - Dette — PDF légal & montant_paye (à clarifier) : facture_pdf_service.rb (GELÉ
    STRICT) lit montant_paye (figé à 0) pour imprimer « Déjà payé » et le
    reste-à-payer sur le PDF. Si le PDF est un instantané d'émission, 0 est correct
    par construction (invariant BT-113) ; s'il est régénéré à la demande après des
    paiements, il afficherait un reste périmé. À clarifier avec Sébastien. Fichier
    gelé → toute correction passerait par une décision de dégel, hors sprint
    relances. Le reste-à-payer VIVANT est déjà correctement dérivé par
    PaiementSyntheseService (UI).

  - Dette — FK relances→factures en restrict_with_exception : une facture ayant
    reçu au moins une relance devient indestructible (même piège que
    evenements_facture). Cohérent avec l'append-only ; à garder en tête si un flux
    de suppression de facture est un jour ouvert.

  - Dette (mineure) — divergence de pattern front : la section relance met à jour
    la facture depuis la réponse du POST, alors que les paiements refetchent.
    Fonctionnel (l'endpoint renvoie :with_details), à harmoniser un jour pour la
    cohérence.

### Dettes — Relances v1b (planificateur) + Portail MVP (exécutions des 13/08/2026)

### Dette n°30 — règle de méthode : ne jamais éditer db/schema.rb à la main
- **Sévérité** : INFO (règle de process, pas un bug)
- **Statut** : NON RÉSOLUE (règle permanente, appliquée dès à présent)
- **Preuve** : pendant v1b, `db/schema.rb` a été retouché à la main pour annuler un artefact cosmétique `::text` régénéré par `db:migrate` (cf. dette n°7). Cette retouche manuelle a MASQUÉ une incohérence : la migration créait l'index d'idempotence avec un prédicat erroné (`statut = 'planifie'`, une valeur inexistante) tandis que le `schema.rb` corrigé à la main portait le bon prédicat. Les tests sont restés verts parce que la base de TEST se charge depuis `schema.rb` (bon prédicat), alors que dev/prod/CI passent par la MIGRATION (mauvais prédicat) — « vert en test, cassé en vrai ». Détecté et corrigé au test manuel de Sébastien.
- **Impact / pourquoi c'est une dette** : éditer un fichier généré peut désynchroniser migration↔schema sans que la suite ne l'attrape. C'est un trou de filet méthodologique, pas un défaut de code.
- **Quand la traiter** : règle en vigueur. On laisse TOUJOURS `db:migrate` régénérer `schema.rb` ; le bruit `::text` se tolère (n°7). La vérité en base se contrôle par `ActiveRecord::Base.connection.indexes(...)`, jamais par une édition manuelle du dump.

### Dette n°31 — Brakeman non rejoué en local sur v1b et le portail
- **Sévérité** : BASSE
- **Statut** : NON RÉSOLUE
- **Preuve** : `bin/brakeman` n'a pas pu tourner en local lors de v1b (erreur SSL liée à l'inspection HTTPS d'Avast) et n'a pas été relancé au sprint portail. Les autres filets sont verts (RSpec, RuboCop côté back ; ESLint, `tsc --noEmit`, Vitest côté front).
- **Impact / pourquoi c'est une dette** : l'analyse statique de sécurité Brakeman n'a pas couvert ces deux sprints en local — un trou de filet, pas une faille constatée. Sensible surtout pour le portail (endpoint public).
- **Quand la traiter** : relancer `bin/brakeman` localement (la confiance TLS a été réparée le 26/07, cf. dette n°R6), OU confirmer que la CI l'exécute ; sinon, ajouter un job `brakeman` à `ci.yml` sur le modèle des jobs existants.

### Dette n°32 — planificateur de relances : livraison « au moins une fois »
- **Sévérité** : BASSE (limite assumée)
- **Statut** : NON RÉSOLUE (choix de conception assumé)
- **Preuve** : `RelanceEnvoiJob` envoie l'e-mail HORS transaction (pour ne jamais mentir en cas de rollback), PUIS journalise (`envoyee`/`echec`). Si le process meurt ENTRE l'envoi et l'écriture, un rejeu peut renvoyer le même palier : le mail peut partir deux fois, jamais la journalisation en double (l'index unique partiel `(facture_id, niveau) WHERE statut='envoyee' AND origine='planifie'` est le filet DB).
- **Impact / pourquoi c'est une dette** : un rare doublon de relance possible sur crash. Toléré pour du recouvrement ; on n'a délibérément pas posé de 2-phase commit / outbox pour v1b.
- **Quand la traiter** : dette assumée. Ré-évaluer si un doublon devient gênant (clé d'idempotence / pattern outbox).

### Dette n°33 — pas de rate-limiting sur la résolution publique du token portail
- **Sévérité** : BASSE (à poser avant la production)
- **Statut** : NON RÉSOLUE
- **Preuve** : `Portail::FacturesController` (public, hors JWT) n'a pas de throttle Rack::Attack dédié, contrairement au webhook PA (cf. dette n°R6).
- **Impact / pourquoi c'est une dette** : ZÉRO risque de confidentialité (token de 64 octets → brute-force impraticable), mais un endpoint public non authentifié reste exposé au déni de service.
- **Quand la traiter** : fast-follow avant la prod (V1.5), en réutilisant le pattern `rack-attack` déjà en place pour le webhook PA (throttle par IP).

### Dette n°34 — token du portail présent dans les logs d'accès
- **Sévérité** : INFO
- **Statut** : NON RÉSOLUE
- **Preuve** : le token opaque est porté dans le CHEMIN de l'URL publique (`/portail/factures/:token`), donc potentiellement journalisé par les logs d'accès serveur/proxy.
- **Impact / pourquoi c'est une dette** : compromis standard de tout lien de partage (comme un lien de réinitialisation de mot de passe), atténué par la révocation et l'expiration à 12 mois.
- **Quand la traiter** : pas d'action requise. À garder en tête au moment du durcissement prod (filtrer les chemins sensibles dans les logs si besoin).

### Dette n°35 — espace client authentifié multi-fournisseurs non conçu (le « vrai » portail)
- **Sévérité** : INFO (chantier produit à cadrer)
- **Statut** : NON RÉSOLUE (choix de séquencement : le lien-par-facture d'abord)
- **Preuve** : le portail MVP est un PARTAGE de facture par lien opaque, PAS un espace client. Le modèle `client` actuel est scopé à UNE organisation (créé par un owner). Un vrai espace client — le destinataire se connecte (login + mot de passe) et retrouve TOUS ses fournisseurs Sereno et l'historique de ses factures (en attente / payées) — suppose une notion d'identité NOUVELLE, un « compte destinataire » vivant AU-DESSUS des organisations et rattaché à plusieurs `client`.
- **Impact / pourquoi c'est une dette** : c'est un pan de données ET d'auth à part entière (inscription, mot de passe hashé, réinitialisation, vérification e-mail, sessions destinataire, RGPD côté destinataire), à cadrer comme un produit distinct — pas une extension du portail MVP. Le MVP en pose néanmoins la première brique de sécurité (patron token/hash réutilisable).
- **Quand la traiter** : à cadrer explicitement (valeur produit, périmètre, identité destinataire) AVANT toute construction. Décision de Sébastien.

### Dettes — Lien du portail dans la relance (fast-follow du 15/08/2026)

### Dette n°36 — FRONTEND_URL requise en production (désormais enforcée)
- **Sévérité** : INFO (durcissement, pas un bug constaté)
- **Statut** : NON RÉSOLUE (prérequis de déploiement)
- **Preuve** : la base d'URL du portail lève une erreur claire en prod si FRONTEND_URL est absente ou invalide (placeholder supprimé).
- **Impact / pourquoi c'est une dette** : Prérequis de déploiement (V1.5) : positionner FRONTEND_URL dans les secrets de prod avec le vrai domaine avant tout envoi de lien/relance.
- **Quand la traiter** : avant le premier déploiement en production — sans quoi TOUT envoi de relance (manuel et auto) échouerait (journalisé "echec", jamais un lien cassé envoyé).

### Dette n°37 — plusieurs liens de portail actifs par facture
- **Sévérité** : BASSE
- **Statut** : NON RÉSOLUE (choix assumé)
- **Preuve** : une relance crée un token sans révoquer les autres (choix assumé pour ne jamais tuer en silence un lien partagé à la main). Il n'existe pas encore de vue « liste des liens actifs » : le bouton owner « Révoquer » reste global (révoque TOUS les liens d'un coup), et l'action owner « Générer » révoque puis recrée (donc peut révoquer des liens issus de relances — action explicite de l'owner, pas silencieuse).
- **Impact / pourquoi c'est une dette** : accumulation de liens actifs au fil des relances (un token de plus par envoi), sans risque de confidentialité nouveau (chaque token reste un secret indépendant de 128 caractères hex, révocable globalement par l'owner).
- **Quand la traiter** : à affiner si un jour on veut cibler/lister les liens individuellement.

## Dettes résolues

### Dette n°10 — validateurs de conformité non automatisés en CI
- **Sévérité** : (résolue pour son périmètre — était MOYENNE)
- **Statut** : RÉSOLUE pour son périmètre — sprint B4 étages 1 & 2 (mergé dans `main`). France CTC reste hors CI, désormais tracé à part (dette n°24).
- **Preuve** : le job `conformite` de `.github/workflows/ci.yml` exécute à chaque push, sur le runner Linux, la tâche `conformite:valider` (`backend/lib/tasks/conformite.rake`) qui émet un 380 et un 381 en TVA standard ET en franchise (4 artefacts), puis les valide par des validateurs tiers reconnus : **Mustang / KoSIT** pour XSD + Schematron EN 16931 (via le Schematron FeRD compilé et vendoré dans `backend/vendor/facturx_validation_tooling/`), et **veraPDF 1.30.2** pour PDF/A-3b. Le gate exige ACCEPTABLE + 0 failed-assert sur les 4 XML et conformité PDF/A-3b sur les 4 PDF, et **prouve en continu qu'il sait recaler** (deux auto-tests négatifs : un XML corrompu et un PDF non-PDF/A doivent être REJECT, sinon le gate échoue). Job vert vérifié sur PR (`CI / conformite`, ~59 s sur ubuntu-latest).
- **Impact / pourquoi c'était une dette** : la conformité ne reposait que sur des tests internes, jamais rejouée par un validateur officiel à chaque commit. Trois des quatre niveaux (structure XSD, règles EN 16931, PDF/A-3b) sont désormais re-prouvés automatiquement, sur facture ET avoir — fermant durablement l'écart entre « conformité affirmée » et « conformité prouvée en continu ».
- **Point clé tranché** : le PDF de l'avoir (381, avec filigrane) n'avait **jamais** été validé PDF/A-3b — il l'est désormais : 146/146, conforme (le filigrane DeviceGray plein, sans transparence, ne casse rien).
- **Quand ça a été traité** : sprint B4, découpé en étage 0 (spike outillage), étage 1 (XSD + Schematron en CI) et étage 2 (veraPDF en CI), comme prévu.

### Dette n°13 — fichiers des avoirs (XML) stockés dans storage/factures/
- **Sévérité** : (résolue — était BASSE)
- **Statut** : RÉSOLUE — fix stockage (cloisonnement par environnement), mergé dans `main`
- **Preuve** : le XML d'un avoir était écrit sous `storage/factures/` parce que `AvoirEmissionService` réutilisait `FacturXStorageService` (codé en dur « factures »). Désormais, un service dédié `backend/app/services/avoir_xml_storage_service.rb` (LIBRE, voie b — miroir de `FacturXStorageService`) route le XML d'avoir sous `storage/<env>/avoirs/<id>/`, comme son PDF. `AvoirEmissionService` a été mis à jour pour l'appeler. Prouvé par T-AVOIR-XML-EMPLACEMENT (`avoir_emis.xml_url.include?("/avoirs/")` → true).
- **Impact / pourquoi c'était une dette** : les artefacts d'un avoir atterrissaient dans un dossier « factures », trompeur à l'inspection. Résolu en même temps que le cloisonnement du stockage par environnement (qui a aussi corrigé le bug plus grave du PDF/XML rasé par un test non scopé).
- **Quand ça a été traité** : fix stockage, à l'occasion de l'investigation du bug « PDF archivé indisponible » — même famille de problème (emplacements de stockage mal cloisonnés).

### Dette n°17 — pas d'endpoint API de gestion des lignes d'un avoir
- **Sévérité** : (résolue — était MOYENNE)
- **Statut** : RÉSOLUE — sprint V1.2b-bis (mergé dans `main`)
- **Preuve** : `backend/app/controllers/api/v1/lignes_avoir_controller.rb` expose désormais create/update/delete des lignes d'un avoir, en routes nichées sous `/avoirs/:avoir_id/lignes`. Le recalcul des totaux est entièrement porté côté backend par les callbacks déjà présents depuis V1.2a (`LigneAvoir#after_save`/`after_destroy → Avoir#recalculer_totaux!`) — zéro logique de calcul ajoutée. L'immutabilité après émission est garantie par le modèle (une opération sur un avoir émis échoue → 422), pas par la policy (cohérent avec la règle policy≠éligibilité). Isolation cross-tenant → 404. Prouvé par `spec/requests/api/v1/lignes_avoir_spec.rb` (T-LIGNE-IMMUABLE, T-LIGNE-ISOLATION, T-TOTAUX-BACKEND décisifs).
- **Impact / pourquoi c'était une dette** : sans cet endpoint, un avoir créé via l'API naissait sans ligne et ne pouvait être rempli qu'en base directement. Le parcours « créer un avoir avec ses lignes puis l'émettre » était impossible depuis l'application. L'endpoint débloque le formulaire de création frontend (V1.2d).
- **Quand ça a été traité** : sprint V1.2b-bis, comme prérequis bloquant identifié par la reconnaissance V1.2d — avant de construire le frontend.

### Dette n°R6 — endpoint webhook public sans rate limiting
- **Sévérité** : (résolue — était HAUTE, bloquant avant tout déploiement en production)
- **Statut** : RÉSOLUE — commit `f3c2d6a` (PR #4, mergée dans `main`)
- **Preuve** : `backend/config/initializers/rack_attack.rb` déclare un throttle sur `POST /webhooks/pa` à 60 requêtes/minute par IP (Rack::Attack, en middleware, sans jamais lire le corps de la requête — le `raw_post` de la signature reste intact). Le throttle par organisation est appliqué dans `backend/app/controllers/webhooks/pa_controller.rb`, APRÈS la résolution de l'organisation, en réutilisant la primitive `Rack::Attack.cache.count` (même seuil 60/min, même sémantique, mais au bon niveau architectural puisque l'organisation n'est connue qu'après résolution). Au-delà du seuil → 429 Too Many Requests, corps sobre sans fuite d'information. Prouvé par `backend/spec/requests/webhooks/pa_rate_limit_spec.rb` : la 61e requête reçoit 429, l'isolation du compteur par organisation est testée (une organisation qui atteint son seuil n'affecte pas une autre), et une route API authentifiée n'est jamais throttlée par cette règle.
- **Impact / pourquoi c'était une dette** : un endpoint public non throttlé est exposé au déni de service (la signature protège contre les fausses notifications, pas contre l'inondation). C'était la seule dette bloquant-avant-prod du webhook.
- **Point de méthode** : le throttle par organisation a d'abord exigé de constater où l'organisation est identifiée dans la requête. `identifiant_pa` n'existe que dans le corps JSON (ni URL ni header) ; lire le corps au niveau du middleware Rack::Attack aurait vidé le `raw_post` dont dépend la vérification de signature. La solution a donc scindé le throttle (IP en middleware, organisation dans le contrôleur) pour ne jamais compromettre la signature. Les tests B3.3 (raw body, signature, cross-tenant) sont restés verts sans modification — preuve que la couche de throttle n'a rien cassé.
- **Prérequis levé** : l'installation de `rack-attack` nécessitait de réparer la confiance TLS locale (le trousseau de certificats de Ruby était absent, et l'inspection HTTPS d'Avast cassait la vérification). Réparé le 26/07/2026 en installant le trousseau Mozilla officiel (`cacert.pem` de curl.se) plus le certificat racine Avast dans `C:/Ruby40-x64/msys64/ucrt64/etc/ssl/cert.pem` ; `bundle install` fonctionne de nouveau pour toutes les gems.
- **Quand ça a été traité** : sprint R6, juste après la fermeture de la couche transmission (B3.3), avant tout déploiement — comme prévu.

### Dette n°1 — credentials_chiffres stocké en clair
- **Sévérité** : (résolue — était HAUTE, seule dette HAUTE du projet)
- **Statut** : RÉSOLUE — sprint B5 (mergé dans `main`)
- **Preuve** : `backend/app/models/plateforme_agreee.rb` déclare désormais `encrypts :credentials_chiffres` (ActiveRecord::Encryption, non déterministe, clés lues depuis l'environnement — B5). Le chiffrement au repos est prouvé par `backend/spec/models/plateforme_agreee_spec.rb` (test décisif : écriture via le modèle puis lecture SQL brute → la valeur au repos ne contient jamais le clair). La discordance avec `dictionnaire_donnees_sereno.md` (« Rails encrypted ») est désormais résolue : la promesse est tenue.
- **Impact / pourquoi c'était une dette** : le nom et la documentation promettaient un chiffrement absent. Traité pendant que la colonne était encore morte (aucune donnée à migrer) — coût minimal.
- **Quand ça a été traité** : sprint B5, avant tout branchement à une PA réelle, comme prévu.

### Dette n°4 — requires_review sans mécanisme de résolution ni visibilité persistante
- **Sévérité** : (résolue — était MOYENNE)
- **Statut** : RÉSOLUE — sprint B3.2 (mergé dans `main`)
- **Preuve** : `backend/app/services/pa_requires_review_counter.rb` calcule, pour l'organisation courante, le nombre de transmissions dont le DERNIER événement entrant est `requires_review` (piste A « le dernier événement fait foi », via `DISTINCT ON` sur la clé temporelle de l'ingestion). Exposé via l'API et affiché comme badge PERSISTANT dans `frontend/src/components/InvoiceTransmissionSection.tsx` (visible dès le chargement de la page, sans avoir cliqué). La REDESCENTE du compteur est prouvée par `backend/spec/services/pa_requires_review_counter_spec.rb` (une transmission `requires_review` puis `applied` plus récent → compteur retombe à 0), avec scoping organisation testé.
- **Impact / pourquoi c'était une dette** : une contradiction pouvait passer inaperçue faute de visibilité durable. Le badge honnête (monte ET descend) la rend visible en permanence.
- **Quand ça a été traité** : sprint B3.2 (supervision UI), comme prévu. Note : la résolution retenue est la visibilité (piste A) ; un acquittement explicite par clic humain (piste B) reste un chantier séparé non ouvert, volontairement.

### Dette n°8 — bouton de synchronisation à 3 clics devenu 1 clic
- **Sévérité** : (résolue — était MINEURE)
- **Statut** : RÉSOLUE — commit `fbb0cfb`
- **Preuve** : `grep -rn "Vérifier maintenant" frontend/src` → `frontend/src/components/InvoiceTransmissionSection.tsx:172`, bouton unique déclenchant directement la synchronisation. `git log --oneline -S "Vérifier maintenant" -- frontend/src` → `fbb0cfb feat(pa): add automatic polling with backoff, pause and stop conditions`, identifié avec certitude.
- **Impact / pourquoi c'était une dette** : l'ancien parcours sandbox nécessitait 3 clics pour vérifier un statut, ce qui créait une friction artificielle non représentative du produit cible.
- **Quand ça a été traité** : livré avec la tranche B3.1b (polling automatique), qui a renommé et simplifié le bouton en même temps que l'introduction de la vérification automatique en arrière-plan.
