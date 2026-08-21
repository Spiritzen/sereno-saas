import { useEffect, useRef, useState, type FormEventHandler } from "react";
import { Navigate, Link, useNavigate } from "react-router-dom";
import { PublicShell } from "../components/layout/PublicShell";
import { inscrire, parseInscriptionError } from "../api/inscriptionApi";
import { useAuth } from "../context/useAuth";
import type { RegimeTva } from "../types/auth";

type Etape = 1 | 2 | 3;

type ErreursEtape1 = Partial<{
  prenom: string;
  nom: string;
  email: string;
  motDePasse: string;
  confirmationMotDePasse: string;
}>;

type ErreursEtape2 = Partial<{
  raisonSociale: string;
  siret: string;
  regimeTva: string;
  adresseLigne1: string;
  codePostal: string;
  ville: string;
  emailFacturation: string;
}>;

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const REGIME_TVA_LABELS: Record<RegimeTva, string> = {
  franchise: "Franchise en base de TVA",
  reel_simplifie: "Réel simplifié",
  reel_normal: "Réel normal",
};

// R2.1 (backend) — messages EXACTS et STATIQUES levés par
// InscriptionOwnerService#verifier_mot_de_passe! : seuls messages 422 pour
// lesquels une correspondance CHAMP est fiable à 100% (chaînes françaises,
// jamais dérivées d'une humanisation Rails). Cf. rapport §16 : la locale
// Rails par défaut est anglaise (config/locales/en.yml) — tout AUTRE message
// 422 (validations Utilisateur/Organisation, collision DB) n'est donc
// JAMAIS réaffiché tel quel, pour ne jamais exposer de jargon anglais dans
// un formulaire français.
const MESSAGE_MOT_DE_PASSE_OBLIGATOIRE = "Le mot de passe est obligatoire.";
const MESSAGE_MOT_DE_PASSE_COURT = "Le mot de passe doit contenir au moins 8 caractères.";
const MESSAGE_CONFIRMATION_DIFFERENTE = "La confirmation du mot de passe ne correspond pas.";
const MESSAGE_COLLISION_DB = "Cet e-mail ou ce SIRET est déjà utilisé.";
const MESSAGE_GENERIQUE_422 = "Certaines informations ne sont pas valides. Vérifiez votre saisie.";
const MESSAGE_400 = "Certaines informations sont incomplètes. Vérifiez le formulaire.";
const MESSAGE_429 = "Trop de tentatives. Patientez un instant avant de réessayer.";
const MESSAGE_RESEAU = "Sereno ne peut pas créer votre espace pour le moment. Réessayez dans quelques instants.";
const VERROU_SECONDES_DEFAUT = 60;

function normaliserSiret(valeur: string) {
  return valeur.replace(/\D/g, "");
}

function focusPremierChampInvalide(container: HTMLElement | null) {
  const premier = container?.querySelector<HTMLElement>('[aria-invalid="true"]');
  premier?.focus();
}

// R3 (prompt_claude_code_inscription_owner_frontend_r3.txt) — parcours
// d'inscription OWNER en 3 étapes lisibles (Vous / Votre entreprise /
// Vérification), route dédiée /inscription (JAMAIS une modale — trop de
// champs pour une fenêtre compacte, cf. §3.2). Aucun appel backend avant
// l'action finale « Créer mon espace » (§3.2). Toutes les étapes partagent
// le MÊME état local (useState) : revenir à une étape précédente ne perd
// donc jamais les saisies. Chaque étape est son PROPRE <form> (soumis par
// Entrée ou son propre bouton) : la touche Entrée sur l'étape 1 avance à
// l'étape 2, jamais ne déclenche prématurément la création du compte.
export function InscriptionPage() {
  const navigate = useNavigate();
  const { isAuthenticated, completeAuthentication } = useAuth();

  const [etape, setEtape] = useState<Etape>(1);
  const [pageState, setPageState] = useState<"formulaire" | "compte_cree_sans_session">("formulaire");

  // Étape 1 — Vous
  const [prenom, setPrenom] = useState("");
  const [nom, setNom] = useState("");
  const [email, setEmail] = useState("");
  const [motDePasse, setMotDePasse] = useState("");
  const [confirmationMotDePasse, setConfirmationMotDePasse] = useState("");
  const [erreursEtape1, setErreursEtape1] = useState<ErreursEtape1>({});

  // Étape 2 — Votre entreprise
  const [raisonSociale, setRaisonSociale] = useState("");
  const [siret, setSiret] = useState("");
  const [regimeTva, setRegimeTva] = useState<RegimeTva | "">("");
  const [adresseLigne1, setAdresseLigne1] = useState("");
  const [codePostal, setCodePostal] = useState("");
  const [ville, setVille] = useState("");
  // R3 (§6) — tant que ce champ n'a pas été modifié manuellement (`null`),
  // sa valeur AFFICHÉE dérive directement de l'e-mail de connexion — un
  // calcul pendant le rendu, jamais un effet qui recopie un state dans un
  // autre (évite react-hooks/set-state-in-effect ; correspond aussi
  // directement à la règle produit : « tant que l'utilisateur ne l'a pas
  // modifié manuellement, une correction de l'e-mail OWNER continue de le
  // synchroniser »). Dès la première frappe dans ce champ, la valeur exacte
  // saisie est mémorisée et ne suit plus jamais l'e-mail de connexion.
  const [emailFacturationManuelle, setEmailFacturationManuelle] = useState<string | null>(null);
  const emailFacturation = emailFacturationManuelle ?? email;
  const [erreursEtape2, setErreursEtape2] = useState<ErreursEtape2>({});

  // Soumission finale (étape 3)
  const [statutSoumission, setStatutSoumission] = useState<"idle" | "submitting">("idle");
  const [erreurGlobale, setErreurGlobale] = useState<string | null>(null);
  const [messagesValidationGlobaux, setMessagesValidationGlobaux] = useState<string[]>([]);
  const [verrouSecondesRestantes, setVerrouSecondesRestantes] = useState<number | null>(null);
  // Garde anti-double-soumission : une ref (synchrone), pas seulement l'état
  // `disabled` du bouton (qui ne se répercute qu'au rendu suivant — un
  // double-clic synchrone pourrait sinon déclencher deux requêtes avant le
  // premier re-rendu). Mutation négative obligatoire n°1 : ce mécanisme.
  const soumissionEnCoursRef = useRef(false);

  // Compte à rebours 429 — chaînage de setTimeout (jamais setInterval, pour
  // un nettoyage systématique à chaque tick et au démontage) ; testable via
  // de fausses temporisations (vi.useFakeTimers), sans dépendre du temps réel.
  // La transition finale vers `null` se fait UNIQUEMENT dans le callback du
  // setTimeout (jamais un setState synchrone dans le corps de l'effet) :
  // l'effet lui-même se contente de programmer/nettoyer la temporisation.
  useEffect(() => {
    if (verrouSecondesRestantes === null || verrouSecondesRestantes <= 0) {
      return;
    }

    const timeoutId = window.setTimeout(() => {
      setVerrouSecondesRestantes((secondes) => (secondes !== null && secondes > 1 ? secondes - 1 : null));
    }, 1000);

    return () => window.clearTimeout(timeoutId);
  }, [verrouSecondesRestantes]);

  const titreEtape1Ref = useRef<HTMLHeadingElement | null>(null);
  const titreEtape2Ref = useRef<HTMLHeadingElement | null>(null);
  const titreEtape3Ref = useRef<HTMLHeadingElement | null>(null);
  const sectionEtape1Ref = useRef<HTMLFormElement | null>(null);
  const sectionEtape2Ref = useRef<HTMLFormElement | null>(null);
  const hasNavigatedRef = useRef(false);

  // R3 (§13) — focus sur le titre de l'étape après une navigation RÉUSSIE
  // (jamais au montage initial, jamais en cas d'erreur de champ — cf. les
  // effets dédiés ci-dessous qui, eux, focalisent le premier champ invalide).
  useEffect(() => {
    if (!hasNavigatedRef.current) {
      hasNavigatedRef.current = true;
      return;
    }

    const cible = etape === 1 ? titreEtape1Ref : etape === 2 ? titreEtape2Ref : titreEtape3Ref;
    cible.current?.focus();
  }, [etape]);

  useEffect(() => {
    if (Object.keys(erreursEtape1).length > 0) {
      focusPremierChampInvalide(sectionEtape1Ref.current);
    }
  }, [erreursEtape1]);

  useEffect(() => {
    if (Object.keys(erreursEtape2).length > 0) {
      focusPremierChampInvalide(sectionEtape2Ref.current);
    }
  }, [erreursEtape2]);

  if (isAuthenticated) {
    return <Navigate to="/app/dashboard" replace />;
  }

  function validerEtape1(): boolean {
    const erreurs: ErreursEtape1 = {};

    if (!prenom.trim()) {
      erreurs.prenom = "Indiquez votre prénom.";
    }

    if (!nom.trim()) {
      erreurs.nom = "Indiquez votre nom.";
    }

    if (!email.trim()) {
      erreurs.email = "Indiquez votre e-mail.";
    } else if (!EMAIL_REGEX.test(email.trim())) {
      erreurs.email = "Indiquez un e-mail valide.";
    }

    if (!motDePasse) {
      erreurs.motDePasse = "Indiquez un mot de passe.";
    } else if (motDePasse.length < 8) {
      erreurs.motDePasse = "Utilisez au moins 8 caractères.";
    }

    if (!confirmationMotDePasse) {
      erreurs.confirmationMotDePasse = "Confirmez votre mot de passe.";
    } else if (confirmationMotDePasse !== motDePasse) {
      erreurs.confirmationMotDePasse = "Les deux mots de passe sont différents.";
    }

    setErreursEtape1(erreurs);

    return Object.keys(erreurs).length === 0;
  }

  function validerEtape2(): boolean {
    const erreurs: ErreursEtape2 = {};

    if (!raisonSociale.trim()) {
      erreurs.raisonSociale = "Indiquez le nom de votre entreprise.";
    }

    if (!/^\d{14}$/.test(normaliserSiret(siret))) {
      erreurs.siret = "Le SIRET doit contenir 14 chiffres.";
    }

    if (!regimeTva) {
      erreurs.regimeTva = "Choisissez votre régime de TVA.";
    }

    if (!adresseLigne1.trim()) {
      erreurs.adresseLigne1 = "Indiquez votre adresse.";
    }

    if (!codePostal.trim()) {
      erreurs.codePostal = "Indiquez votre code postal.";
    } else if (!/^\d{5}$/.test(codePostal.trim())) {
      erreurs.codePostal = "Le code postal doit contenir 5 chiffres.";
    }

    if (!ville.trim()) {
      erreurs.ville = "Indiquez votre ville.";
    }

    if (!emailFacturation.trim()) {
      erreurs.emailFacturation = "Indiquez un e-mail de facturation.";
    } else if (!EMAIL_REGEX.test(emailFacturation.trim())) {
      erreurs.emailFacturation = "Indiquez un e-mail valide.";
    }

    setErreursEtape2(erreurs);

    return Object.keys(erreurs).length === 0;
  }

  const handleSubmitEtape1: FormEventHandler<HTMLFormElement> = (event) => {
    event.preventDefault();

    if (validerEtape1()) {
      setEtape(2);
    }
  };

  const handleSubmitEtape2: FormEventHandler<HTMLFormElement> = (event) => {
    event.preventDefault();

    if (validerEtape2()) {
      setEtape(3);
    }
  };

  function handleErreurValidation(messages: string[]) {
    const nouvellesErreursEtape1: ErreursEtape1 = {};
    const messagesGlobaux: string[] = [];
    let aUnMessageInconnu = false;

    for (const message of messages) {
      if (message === MESSAGE_MOT_DE_PASSE_OBLIGATOIRE || message === MESSAGE_MOT_DE_PASSE_COURT) {
        nouvellesErreursEtape1.motDePasse = message;
      } else if (message === MESSAGE_CONFIRMATION_DIFFERENTE) {
        nouvellesErreursEtape1.confirmationMotDePasse = message;
      } else if (message === MESSAGE_COLLISION_DB) {
        messagesGlobaux.push(message);
      } else {
        aUnMessageInconnu = true;
      }
    }

    if (aUnMessageInconnu) {
      messagesGlobaux.push(MESSAGE_GENERIQUE_422);
    }

    // Ne revient automatiquement à l'étape 1 QUE si l'échec est
    // exclusivement lié au mot de passe/confirmation ET qu'aucun message
    // global n'a besoin d'être vu à l'étape 3 (cf. §16 du rapport).
    if (messagesGlobaux.length === 0 && Object.keys(nouvellesErreursEtape1).length > 0) {
      setErreursEtape1(nouvellesErreursEtape1);
      setEtape(1);
      return;
    }

    if (Object.keys(nouvellesErreursEtape1).length > 0) {
      setErreursEtape1(nouvellesErreursEtape1);
    }

    setMessagesValidationGlobaux(messagesGlobaux);
  }

  const handleSubmitFinal: FormEventHandler<HTMLFormElement> = async (event) => {
    event.preventDefault();

    // MUTATION NÉGATIVE OBLIGATOIRE n°1 (§16) — cette garde. Sans elle, un
    // double-clic ou une touche Entrée maintenue peut déclencher deux
    // requêtes avant le premier re-rendu (disabled= sur le bouton n'est pas
    // suffisant seul, il ne s'applique qu'au rendu SUIVANT).
    if (soumissionEnCoursRef.current) {
      return;
    }

    soumissionEnCoursRef.current = true;
    setStatutSoumission("submitting");
    setErreurGlobale(null);
    setMessagesValidationGlobaux([]);

    try {
      const reponse = await inscrire({
        utilisateur: {
          prenom: prenom.trim(),
          nom: nom.trim(),
          email: email.trim(),
          mot_de_passe: motDePasse,
          confirmation_mot_de_passe: confirmationMotDePasse,
        },
        organisation: {
          raison_sociale: raisonSociale.trim(),
          siret: normaliserSiret(siret),
          regime_tva: regimeTva as RegimeTva,
          adresse_ligne1: adresseLigne1.trim(),
          code_postal: codePostal.trim(),
          ville: ville.trim(),
          pays: "FR",
          email: emailFacturation.trim(),
        },
      });

      // MUTATION NÉGATIVE OBLIGATOIRE n°2 (§16) — ce branchement sur
      // `session_active`.
      if (reponse.session_active) {
        const hydrate = await completeAuthentication();

        if (hydrate) {
          navigate("/app/dashboard");
          return;
        }
      }

      // session_active:false (documenté, honnête) OU hydratation
      // inattendue en échec malgré session_active:true : même traitement
      // honnête — le compte existe, jamais réinscrit automatiquement.
      setPageState("compte_cree_sans_session");
    } catch (error) {
      const info = parseInscriptionError(error);

      if (info.kind === "validation") {
        handleErreurValidation(info.messages);
      } else if (info.kind === "malformed") {
        setErreurGlobale(MESSAGE_400);
      } else if (info.kind === "rate_limited") {
        setErreurGlobale(MESSAGE_429);
        setVerrouSecondesRestantes(info.retryAfterSeconds ?? VERROU_SECONDES_DEFAUT);
      } else {
        setErreurGlobale(MESSAGE_RESEAU);
      }
    } finally {
      soumissionEnCoursRef.current = false;
      setStatutSoumission("idle");
    }
  };

  if (pageState === "compte_cree_sans_session") {
    return (
      <PublicShell>
        <section className="inscription-page inscription-confirmation">
          <h1>Votre espace est créé</h1>
          <p>
            Votre compte Sereno a bien été créé. Pour des raisons de
            sécurité, connectez-vous pour y accéder.
          </p>
          <Link to="/login" className="primary-btn">
            Se connecter
          </Link>
        </section>
      </PublicShell>
    );
  }

  const verrouActif = verrouSecondesRestantes !== null && verrouSecondesRestantes > 0;

  return (
    <PublicShell>
      <section className="inscription-page">
        <p className="page-kicker">Créer mon espace</p>
        <h1>Bienvenue chez Sereno.</h1>
        <p className="inscription-page__intro">
          Trois étapes courtes, puis vous accédez directement à votre cockpit.
        </p>

        <ol className="inscription-steps" aria-label="Étapes de l'inscription">
          <li
            className={`inscription-steps__item${etape === 1 ? " is-current" : ""}${etape > 1 ? " is-done" : ""}`}
            aria-current={etape === 1 ? "step" : undefined}
          >
            <span className="inscription-steps__number">1</span> Vous
          </li>
          <li
            className={`inscription-steps__item${etape === 2 ? " is-current" : ""}${etape > 2 ? " is-done" : ""}`}
            aria-current={etape === 2 ? "step" : undefined}
          >
            <span className="inscription-steps__number">2</span> Votre entreprise
          </li>
          <li
            className={`inscription-steps__item${etape === 3 ? " is-current" : ""}`}
            aria-current={etape === 3 ? "step" : undefined}
          >
            <span className="inscription-steps__number">3</span> Vérification
          </li>
        </ol>

        {/* `noValidate` sur les 3 <form> de cette page : sans lui, la
            validation NATIVE du navigateur sur `type="email"` (même sans
            `required`) bloque purement et simplement l'événement submit dès
            qu'une valeur non vide ne ressemble pas à un e-mail — le message
            français personnalisé ci-dessous ne serait ALORS jamais atteint,
            une bulle native (non stylée, non française) apparaissant à la
            place. La validation reste donc entièrement portée par
            validerEtape1/validerEtape2 ci-dessous, jamais par le
            navigateur. */}
        {etape === 1 && (
          <form
            className="inscription-form"
            onSubmit={handleSubmitEtape1}
            ref={sectionEtape1Ref}
            noValidate
          >
            <h2 ref={titreEtape1Ref} tabIndex={-1}>
              Vous
            </h2>
            <p className="inscription-form__intro">Quelques informations pour créer votre compte.</p>

            <div className="inscription-form-grid">
              <label>
                Prénom <span className="required-mark">*</span>
                <input
                  type="text"
                  value={prenom}
                  autoComplete="given-name"
                  aria-invalid={Boolean(erreursEtape1.prenom)}
                  aria-describedby={erreursEtape1.prenom ? "erreur-prenom" : undefined}
                  onChange={(event) => setPrenom(event.target.value)}
                />
                {erreursEtape1.prenom && (
                  <span id="erreur-prenom" className="field-error">
                    {erreursEtape1.prenom}
                  </span>
                )}
              </label>

              <label>
                Nom <span className="required-mark">*</span>
                <input
                  type="text"
                  value={nom}
                  autoComplete="family-name"
                  aria-invalid={Boolean(erreursEtape1.nom)}
                  aria-describedby={erreursEtape1.nom ? "erreur-nom" : undefined}
                  onChange={(event) => setNom(event.target.value)}
                />
                {erreursEtape1.nom && (
                  <span id="erreur-nom" className="field-error">
                    {erreursEtape1.nom}
                  </span>
                )}
              </label>

              <label className="inscription-form-wide">
                E-mail de connexion <span className="required-mark">*</span>
                <input
                  type="email"
                  value={email}
                  autoComplete="email"
                  aria-invalid={Boolean(erreursEtape1.email)}
                  aria-describedby={erreursEtape1.email ? "erreur-email" : undefined}
                  onChange={(event) => setEmail(event.target.value)}
                />
                {erreursEtape1.email && (
                  <span id="erreur-email" className="field-error">
                    {erreursEtape1.email}
                  </span>
                )}
              </label>

              <label>
                Mot de passe <span className="required-mark">*</span>
                <input
                  type="password"
                  value={motDePasse}
                  autoComplete="new-password"
                  aria-invalid={Boolean(erreursEtape1.motDePasse)}
                  aria-describedby={erreursEtape1.motDePasse ? "erreur-mot-de-passe" : undefined}
                  onChange={(event) => setMotDePasse(event.target.value)}
                />
                {erreursEtape1.motDePasse && (
                  <span id="erreur-mot-de-passe" className="field-error">
                    {erreursEtape1.motDePasse}
                  </span>
                )}
              </label>

              <label>
                Confirmation du mot de passe <span className="required-mark">*</span>
                <input
                  type="password"
                  value={confirmationMotDePasse}
                  autoComplete="new-password"
                  aria-invalid={Boolean(erreursEtape1.confirmationMotDePasse)}
                  aria-describedby={
                    erreursEtape1.confirmationMotDePasse ? "erreur-confirmation" : undefined
                  }
                  onChange={(event) => setConfirmationMotDePasse(event.target.value)}
                />
                {erreursEtape1.confirmationMotDePasse && (
                  <span id="erreur-confirmation" className="field-error">
                    {erreursEtape1.confirmationMotDePasse}
                  </span>
                )}
              </label>
            </div>

            <div className="inscription-actions">
              <button type="submit" className="primary-btn">
                Continuer
              </button>
            </div>
          </form>
        )}

        {etape === 2 && (
          <form
            className="inscription-form"
            onSubmit={handleSubmitEtape2}
            ref={sectionEtape2Ref}
            noValidate
          >
            <h2 ref={titreEtape2Ref} tabIndex={-1}>
              Votre entreprise
            </h2>
            <p className="inscription-form__intro">
              Ces informations apparaîtront sur vos factures.
            </p>

            <div className="inscription-form-grid">
              <label className="inscription-form-wide">
                Raison sociale <span className="required-mark">*</span>
                <input
                  type="text"
                  value={raisonSociale}
                  autoComplete="organization"
                  aria-invalid={Boolean(erreursEtape2.raisonSociale)}
                  aria-describedby={erreursEtape2.raisonSociale ? "erreur-raison-sociale" : undefined}
                  onChange={(event) => setRaisonSociale(event.target.value)}
                />
                {erreursEtape2.raisonSociale && (
                  <span id="erreur-raison-sociale" className="field-error">
                    {erreursEtape2.raisonSociale}
                  </span>
                )}
              </label>

              <label>
                SIRET <span className="required-mark">*</span>
                <input
                  type="text"
                  value={siret}
                  inputMode="numeric"
                  placeholder="14 chiffres"
                  aria-invalid={Boolean(erreursEtape2.siret)}
                  aria-describedby={erreursEtape2.siret ? "erreur-siret" : undefined}
                  onChange={(event) => setSiret(event.target.value)}
                />
                {erreursEtape2.siret && (
                  <span id="erreur-siret" className="field-error">
                    {erreursEtape2.siret}
                  </span>
                )}
              </label>

              <label>
                Régime de TVA <span className="required-mark">*</span>
                <select
                  value={regimeTva}
                  aria-invalid={Boolean(erreursEtape2.regimeTva)}
                  aria-describedby={erreursEtape2.regimeTva ? "erreur-regime-tva" : undefined}
                  onChange={(event) => setRegimeTva(event.target.value as RegimeTva)}
                >
                  <option value="">Choisissez votre régime</option>
                  <option value="franchise">{REGIME_TVA_LABELS.franchise}</option>
                  <option value="reel_simplifie">{REGIME_TVA_LABELS.reel_simplifie}</option>
                  <option value="reel_normal">{REGIME_TVA_LABELS.reel_normal}</option>
                </select>
                {erreursEtape2.regimeTva && (
                  <span id="erreur-regime-tva" className="field-error">
                    {erreursEtape2.regimeTva}
                  </span>
                )}
              </label>

              <label className="inscription-form-wide">
                Adresse <span className="required-mark">*</span>
                <input
                  type="text"
                  value={adresseLigne1}
                  autoComplete="address-line1"
                  aria-invalid={Boolean(erreursEtape2.adresseLigne1)}
                  aria-describedby={erreursEtape2.adresseLigne1 ? "erreur-adresse" : undefined}
                  onChange={(event) => setAdresseLigne1(event.target.value)}
                />
                {erreursEtape2.adresseLigne1 && (
                  <span id="erreur-adresse" className="field-error">
                    {erreursEtape2.adresseLigne1}
                  </span>
                )}
              </label>

              <label>
                Code postal <span className="required-mark">*</span>
                <input
                  type="text"
                  value={codePostal}
                  inputMode="numeric"
                  autoComplete="postal-code"
                  placeholder="80000"
                  aria-invalid={Boolean(erreursEtape2.codePostal)}
                  aria-describedby={erreursEtape2.codePostal ? "erreur-code-postal" : undefined}
                  onChange={(event) => setCodePostal(event.target.value)}
                />
                {erreursEtape2.codePostal && (
                  <span id="erreur-code-postal" className="field-error">
                    {erreursEtape2.codePostal}
                  </span>
                )}
              </label>

              <label>
                Ville <span className="required-mark">*</span>
                <input
                  type="text"
                  value={ville}
                  autoComplete="address-level2"
                  aria-invalid={Boolean(erreursEtape2.ville)}
                  aria-describedby={erreursEtape2.ville ? "erreur-ville" : undefined}
                  onChange={(event) => setVille(event.target.value)}
                />
                {erreursEtape2.ville && (
                  <span id="erreur-ville" className="field-error">
                    {erreursEtape2.ville}
                  </span>
                )}
              </label>

              <div className="inscription-field-static">
                <span className="inscription-field-static__label">Pays</span>
                <span className="inscription-field-static__value">France</span>
              </div>

              <label className="inscription-form-wide">
                E-mail de facturation <span className="required-mark">*</span>
                <input
                  type="email"
                  value={emailFacturation}
                  autoComplete="email"
                  aria-invalid={Boolean(erreursEtape2.emailFacturation)}
                  aria-describedby="aide-email-facturation"
                  onChange={(event) => setEmailFacturationManuelle(event.target.value)}
                />
                <span id="aide-email-facturation" className="field-help">
                  Cette adresse recevra les informations liées à votre facturation.
                </span>
                {erreursEtape2.emailFacturation && (
                  <span className="field-error">{erreursEtape2.emailFacturation}</span>
                )}
              </label>
            </div>

            <div className="inscription-actions">
              <button type="button" className="secondary-btn" onClick={() => setEtape(1)}>
                Retour
              </button>
              <button type="submit" className="primary-btn">
                Continuer
              </button>
            </div>
          </form>
        )}

        {etape === 3 && (
          <form className="inscription-form" onSubmit={handleSubmitFinal} noValidate>
            <h2 ref={titreEtape3Ref} tabIndex={-1}>
              Vérification
            </h2>
            <p className="inscription-form__intro">
              Vérifiez vos informations avant de créer votre espace.
            </p>

            <dl className="inscription-summary">
              <div>
                <dt>Propriétaire</dt>
                <dd>
                  {prenom} {nom}
                </dd>
              </div>
              <div>
                <dt>E-mail de connexion</dt>
                <dd>{email}</dd>
              </div>
              <div>
                <dt>Entreprise</dt>
                <dd>{raisonSociale}</dd>
              </div>
              <div>
                <dt>SIRET</dt>
                <dd>{normaliserSiret(siret)}</dd>
              </div>
              <div>
                <dt>Régime de TVA</dt>
                <dd>{regimeTva ? REGIME_TVA_LABELS[regimeTva] : ""}</dd>
              </div>
              <div>
                <dt>Adresse</dt>
                <dd>
                  {adresseLigne1}, {codePostal} {ville}, France
                </dd>
              </div>
              <div>
                <dt>E-mail de facturation</dt>
                <dd>{emailFacturation}</dd>
              </div>
            </dl>

            {(erreurGlobale || messagesValidationGlobaux.length > 0) && (
              <div className="state-card error" role="alert">
                {erreurGlobale && <p>{erreurGlobale}</p>}
                {messagesValidationGlobaux.map((message) => (
                  <p key={message}>{message}</p>
                ))}
              </div>
            )}

            <div className="inscription-actions">
              <button type="button" className="secondary-btn" onClick={() => setEtape(1)}>
                Modifier mes informations
              </button>
              <button
                type="submit"
                className="primary-btn"
                disabled={statutSoumission === "submitting" || verrouActif}
              >
                {statutSoumission === "submitting"
                  ? "Création en cours…"
                  : verrouActif
                    ? `Patientez ${verrouSecondesRestantes}s`
                    : "Créer mon espace"}
              </button>
            </div>
          </form>
        )}
      </section>
    </PublicShell>
  );
}
