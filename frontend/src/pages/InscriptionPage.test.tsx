import { act, fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { AxiosHeaders } from "axios";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { afterEach, describe, expect, it, vi } from "vitest";
import * as authApi from "../api/authApi";
import * as inscriptionApi from "../api/inscriptionApi";
import { AuthProvider } from "../context/AuthProvider";
import { InscriptionPage } from "./InscriptionPage";

vi.mock("../api/authApi");
vi.mock("../api/inscriptionApi", async (importOriginal) => {
  const original = await importOriginal<typeof import("../api/inscriptionApi")>();
  return {
    ...original,
    inscrire: vi.fn(),
  };
});

const UTILISATEUR_MOCK = {
  id: "u1",
  email: "sebastien@example.test",
  nom: "Cantrelle",
  prenom: "Sébastien",
  role: "owner" as const,
  actif: true,
};

const ORGANISATION_MOCK = {
  id: "o1",
  raison_sociale: "Studio Démo",
  siret: "12345678901234",
  regime_tva: "reel_normal",
};

function renderInscriptionPage(initialPath = "/inscription") {
  return render(
    <MemoryRouter initialEntries={[initialPath]}>
      <AuthProvider>
        <Routes>
          <Route path="/inscription" element={<InscriptionPage />} />
          <Route path="/app/dashboard" element={<div>Cockpit privé</div>} />
          <Route path="/login" element={<div>Page de connexion</div>} />
        </Routes>
      </AuthProvider>
    </MemoryRouter>,
  );
}

async function remplirEtape1(
  user: ReturnType<typeof userEvent.setup>,
  overrides: Partial<{
    prenom: string;
    nom: string;
    email: string;
    motDePasse: string;
    confirmation: string;
  }> = {},
) {
  const valeurs = {
    prenom: "Sébastien",
    nom: "Cantrelle",
    email: "sebastien@example.test",
    motDePasse: "mot-de-passe-solide",
    confirmation: "mot-de-passe-solide",
    ...overrides,
  };

  await user.clear(screen.getByLabelText(/Prénom/));
  if (valeurs.prenom) await user.type(screen.getByLabelText(/Prénom/), valeurs.prenom);

  await user.clear(screen.getByLabelText(/^Nom/));
  if (valeurs.nom) await user.type(screen.getByLabelText(/^Nom/), valeurs.nom);

  await user.clear(screen.getByLabelText(/E-mail de connexion/));
  if (valeurs.email) await user.type(screen.getByLabelText(/E-mail de connexion/), valeurs.email);

  await user.clear(screen.getByLabelText(/^Mot de passe/));
  if (valeurs.motDePasse) await user.type(screen.getByLabelText(/^Mot de passe/), valeurs.motDePasse);

  await user.clear(screen.getByLabelText(/Confirmation du mot de passe/));
  if (valeurs.confirmation) {
    await user.type(screen.getByLabelText(/Confirmation du mot de passe/), valeurs.confirmation);
  }
}

async function remplirEtape2(
  user: ReturnType<typeof userEvent.setup>,
  overrides: Partial<{
    raisonSociale: string;
    siret: string;
    regimeTva: string;
    adresseLigne1: string;
    codePostal: string;
    ville: string;
    emailFacturation: string;
  }> = {},
) {
  const valeurs = {
    raisonSociale: "Studio Démo",
    siret: "12345678901234",
    regimeTva: "reel_normal",
    adresseLigne1: "1 rue de la Paix",
    codePostal: "80000",
    ville: "Amiens",
    ...overrides,
  };

  await user.clear(screen.getByLabelText(/Raison sociale/));
  if (valeurs.raisonSociale) await user.type(screen.getByLabelText(/Raison sociale/), valeurs.raisonSociale);

  await user.clear(screen.getByLabelText(/SIRET/));
  if (valeurs.siret) await user.type(screen.getByLabelText(/SIRET/), valeurs.siret);

  if (valeurs.regimeTva) {
    await user.selectOptions(screen.getByLabelText(/Régime de TVA/), valeurs.regimeTva);
  }

  await user.clear(screen.getByLabelText(/^Adresse/));
  if (valeurs.adresseLigne1) await user.type(screen.getByLabelText(/^Adresse/), valeurs.adresseLigne1);

  await user.clear(screen.getByLabelText(/Code postal/));
  if (valeurs.codePostal) await user.type(screen.getByLabelText(/Code postal/), valeurs.codePostal);

  await user.clear(screen.getByLabelText(/^Ville/));
  if (valeurs.ville) await user.type(screen.getByLabelText(/^Ville/), valeurs.ville);

  if (overrides.emailFacturation !== undefined) {
    await user.clear(screen.getByLabelText(/E-mail de facturation/));
    await user.type(screen.getByLabelText(/E-mail de facturation/), overrides.emailFacturation);
  }
}

async function avancerJusquaVerification(user: ReturnType<typeof userEvent.setup>) {
  await remplirEtape1(user);
  await user.click(screen.getByRole("button", { name: "Continuer" }));
  await remplirEtape2(user);
  await user.click(screen.getByRole("button", { name: "Continuer" }));
  await screen.findByRole("heading", { name: "Vérification" });
}

function reponseSucces(sessionActive: boolean) {
  return {
    message: "Inscription réussie",
    utilisateur: UTILISATEUR_MOCK,
    organisation: ORGANISATION_MOCK,
    session_active: sessionActive,
  };
}

function erreurAxios(status: number, data: unknown, headers: Record<string, string> = {}) {
  return {
    isAxiosError: true,
    response: { status, data, headers: new AxiosHeaders(headers) },
  };
}

afterEach(() => {
  window.localStorage.clear();
  vi.useRealTimers();
  vi.clearAllMocks();
});

describe("InscriptionPage — étape 1 (Vous)", () => {
  it("rend l'étape 1 avec labels visibles et autocomplete corrects", () => {
    renderInscriptionPage();

    expect(screen.getByRole("heading", { name: "Vous" })).toBeInTheDocument();
    expect(screen.getByLabelText(/Prénom/)).toHaveAttribute("autocomplete", "given-name");
    expect(screen.getByLabelText(/^Nom/)).toHaveAttribute("autocomplete", "family-name");
    expect(screen.getByLabelText(/E-mail de connexion/)).toHaveAttribute("autocomplete", "email");
    expect(screen.getByLabelText(/^Mot de passe/)).toHaveAttribute("autocomplete", "new-password");
    expect(screen.getByLabelText(/Confirmation du mot de passe/)).toHaveAttribute(
      "autocomplete",
      "new-password",
    );
  });

  it("valide localement SANS appeler le backend (requis, e-mail plausible, 8 caractères, confirmation identique)", async () => {
    const user = userEvent.setup();
    renderInscriptionPage();

    await user.click(screen.getByRole("button", { name: "Continuer" }));

    expect(await screen.findByText("Indiquez votre prénom.")).toBeInTheDocument();
    expect(screen.getByText("Indiquez votre nom.")).toBeInTheDocument();
    expect(screen.getByText("Indiquez votre e-mail.")).toBeInTheDocument();
    expect(screen.getByText("Indiquez un mot de passe.")).toBeInTheDocument();
    expect(inscriptionApi.inscrire).not.toHaveBeenCalled();

    await remplirEtape1(user, { email: "pas-un-email", motDePasse: "court", confirmation: "different" });
    await user.click(screen.getByRole("button", { name: "Continuer" }));

    expect(await screen.findByText("Indiquez un e-mail valide.")).toBeInTheDocument();
    expect(screen.getByText("Utilisez au moins 8 caractères.")).toBeInTheDocument();
    expect(inscriptionApi.inscrire).not.toHaveBeenCalled();
  });

  it("confirmation différente -> message dédié, toujours aucun appel API", async () => {
    const user = userEvent.setup();
    renderInscriptionPage();

    await remplirEtape1(user, { confirmation: "autre-chose" });
    await user.click(screen.getByRole("button", { name: "Continuer" }));

    expect(await screen.findByText("Les deux mots de passe sont différents.")).toBeInTheDocument();
    expect(inscriptionApi.inscrire).not.toHaveBeenCalled();
  });
});

describe("InscriptionPage — navigation entre étapes", () => {
  it("navigue 1 → 2 → 3, retour à l'étape 1 sans perte des saisies", async () => {
    // Timeout étendu (interactions nombreuses — remplissage complet des 2
    // premières étapes + retour) : peut dépasser les 5000ms par défaut sous
    // charge (suite complète, exécution parallèle des fichiers de test).
    const user = userEvent.setup();
    renderInscriptionPage();

    await avancerJusquaVerification(user);

    const resume = screen.getByRole("heading", { name: "Vérification" }).closest("form") as HTMLElement;
    expect(within(resume).getByText("Sébastien Cantrelle")).toBeInTheDocument();
    expect(within(resume).getByText("Studio Démo")).toBeInTheDocument();
    expect(within(resume).getByText("12345678901234")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Modifier mes informations" }));

    expect(await screen.findByRole("heading", { name: "Vous" })).toBeInTheDocument();
    expect(screen.getByLabelText(/Prénom/)).toHaveValue("Sébastien");
    expect(screen.getByLabelText(/E-mail de connexion/)).toHaveValue("sebastien@example.test");

    await user.click(screen.getByRole("button", { name: "Continuer" }));

    expect(await screen.findByRole("heading", { name: "Votre entreprise" })).toBeInTheDocument();
    expect(screen.getByLabelText(/Raison sociale/)).toHaveValue("Studio Démo");
  }, 15000);

  it("aria-current='step' marque l'étape active", async () => {
    const user = userEvent.setup();
    renderInscriptionPage();

    const etapes = screen.getAllByRole("listitem");
    expect(etapes[0]).toHaveAttribute("aria-current", "step");

    await remplirEtape1(user);
    await user.click(screen.getByRole("button", { name: "Continuer" }));

    await waitFor(() => {
      const etapesApres = screen.getAllByRole("listitem");
      expect(etapesApres[1]).toHaveAttribute("aria-current", "step");
    });
  });
});

describe("InscriptionPage — étape 2 (Votre entreprise)", () => {
  it("synchronise l'e-mail de facturation avec l'e-mail de connexion jusqu'à modification manuelle", async () => {
    const user = userEvent.setup();
    renderInscriptionPage();

    await remplirEtape1(user, { email: "premier@example.test" });
    await user.click(screen.getByRole("button", { name: "Continuer" }));

    await screen.findByRole("heading", { name: "Votre entreprise" });
    expect(screen.getByLabelText(/E-mail de facturation/)).toHaveValue("premier@example.test");

    // Retour à l'étape 1, changement d'e-mail : la facturation continue de suivre.
    await user.click(screen.getByRole("button", { name: "Retour" }));
    await user.clear(screen.getByLabelText(/E-mail de connexion/));
    await user.type(screen.getByLabelText(/E-mail de connexion/), "second@example.test");
    await user.click(screen.getByRole("button", { name: "Continuer" }));

    await screen.findByRole("heading", { name: "Votre entreprise" });
    expect(screen.getByLabelText(/E-mail de facturation/)).toHaveValue("second@example.test");

    // Modification manuelle : la synchronisation s'arrête définitivement.
    await user.clear(screen.getByLabelText(/E-mail de facturation/));
    await user.type(screen.getByLabelText(/E-mail de facturation/), "facturation-dediee@example.test");

    await user.click(screen.getByRole("button", { name: "Retour" }));
    await user.clear(screen.getByLabelText(/E-mail de connexion/));
    await user.type(screen.getByLabelText(/E-mail de connexion/), "troisieme@example.test");
    await user.click(screen.getByRole("button", { name: "Continuer" }));

    await screen.findByRole("heading", { name: "Votre entreprise" });
    expect(screen.getByLabelText(/E-mail de facturation/)).toHaveValue("facturation-dediee@example.test");
  }, 20000);

  it("SIRET : les espaces de saisie sont tolérés, la valeur envoyée est normalisée en 14 chiffres", async () => {
    const user = userEvent.setup();
    vi.mocked(inscriptionApi.inscrire).mockResolvedValue(reponseSucces(false));

    renderInscriptionPage();

    await remplirEtape1(user);
    await user.click(screen.getByRole("button", { name: "Continuer" }));
    await remplirEtape2(user, { siret: "123 456 789 01234" });
    await user.click(screen.getByRole("button", { name: "Continuer" }));
    await screen.findByRole("heading", { name: "Vérification" });

    await user.click(screen.getByRole("button", { name: "Créer mon espace" }));

    await waitFor(() => expect(inscriptionApi.inscrire).toHaveBeenCalledTimes(1));
    const payloadEnvoye = vi.mocked(inscriptionApi.inscrire).mock.calls[0][0];
    expect(payloadEnvoye.organisation.siret).toBe("12345678901234");
  });

  it("le pays est fixé à FR (jamais éditable), présenté « France »", async () => {
    const user = userEvent.setup();
    renderInscriptionPage();

    await avancerJusquaVerification(user);

    expect(screen.getByText(/, France$/)).toBeInTheDocument();
  });
});

describe("InscriptionPage — étape 3 (Vérification) et soumission", () => {
  it("le régime de TVA propose exactement les 3 valeurs backend, avec des libellés lisibles", async () => {
    const user = userEvent.setup();
    renderInscriptionPage();

    await remplirEtape1(user);
    await user.click(screen.getByRole("button", { name: "Continuer" }));

    const select = screen.getByLabelText(/Régime de TVA/) as HTMLSelectElement;
    const valeurs = Array.from(select.options).map((option) => option.value);

    expect(valeurs).toEqual(["", "franchise", "reel_simplifie", "reel_normal"]);
  });

  it("le résumé ne réaffiche JAMAIS le mot de passe", async () => {
    const user = userEvent.setup();
    renderInscriptionPage();

    await avancerJusquaVerification(user);

    expect(screen.queryByText("mot-de-passe-solide")).not.toBeInTheDocument();
    expect(document.body.textContent).not.toContain("mot-de-passe-solide");
  });

  it("payload final exact : structure imbriquée conforme, AUCUN role/id/organisation_id/actif", async () => {
    const user = userEvent.setup();
    vi.mocked(inscriptionApi.inscrire).mockResolvedValue(reponseSucces(false));

    renderInscriptionPage();
    await avancerJusquaVerification(user);

    await user.click(screen.getByRole("button", { name: "Créer mon espace" }));

    await waitFor(() => expect(inscriptionApi.inscrire).toHaveBeenCalledTimes(1));
    const payloadEnvoye = vi.mocked(inscriptionApi.inscrire).mock.calls[0][0];

    expect(payloadEnvoye).toEqual({
      utilisateur: {
        prenom: "Sébastien",
        nom: "Cantrelle",
        email: "sebastien@example.test",
        mot_de_passe: "mot-de-passe-solide",
        confirmation_mot_de_passe: "mot-de-passe-solide",
      },
      organisation: {
        raison_sociale: "Studio Démo",
        siret: "12345678901234",
        regime_tva: "reel_normal",
        adresse_ligne1: "1 rue de la Paix",
        code_postal: "80000",
        ville: "Amiens",
        pays: "FR",
        email: "sebastien@example.test",
      },
    });

    expect(Object.keys(payloadEnvoye.utilisateur)).not.toContain("role");
    expect(Object.keys(payloadEnvoye.utilisateur)).not.toContain("id");
    expect(Object.keys(payloadEnvoye.utilisateur)).not.toContain("organisation_id");
    expect(Object.keys(payloadEnvoye.utilisateur)).not.toContain("actif");
    expect(Object.keys(payloadEnvoye.organisation)).not.toContain("id");
    expect(Object.keys(payloadEnvoye.organisation)).not.toContain("role");
  });

  it("MUTATION-CIBLE 1 — un double-clic synchrone sur « Créer mon espace » ne déclenche qu'UNE SEULE requête", async () => {
    const user = userEvent.setup();
    vi.mocked(inscriptionApi.inscrire).mockResolvedValue(reponseSucces(false));

    renderInscriptionPage();
    await avancerJusquaVerification(user);

    // fireEvent.submit DIRECTEMENT sur le <form> (jamais un clic sur le
    // bouton) : contourne délibérément l'attribut `disabled` du bouton, qui
    // à lui seul suffirait à bloquer un second CLIC (jsdom, comme un vrai
    // navigateur, ne déclenche aucun événement sur un bouton désactivé) —
    // ce qui masquerait la nécessité réelle de la garde par ref. Deux
    // soumissions du FORMULAIRE lui-même, synchrones, sans attendre entre
    // les deux : seule la garde par ref peut empêcher la seconde requête.
    const form = screen.getByRole("heading", { name: "Vérification" }).closest("form") as HTMLFormElement;
    fireEvent.submit(form);
    fireEvent.submit(form);

    await waitFor(() => expect(inscriptionApi.inscrire).toHaveBeenCalledTimes(1));
  });

  it("succès, session_active:true → AuthProvider hydraté, navigation vers /app/dashboard, jamais un second POST /auth/login", async () => {
    const user = userEvent.setup();
    vi.mocked(inscriptionApi.inscrire).mockResolvedValue(reponseSucces(true));
    vi.mocked(authApi.me).mockResolvedValue({ utilisateur: UTILISATEUR_MOCK, organisation: ORGANISATION_MOCK });

    renderInscriptionPage();
    await avancerJusquaVerification(user);

    await user.click(screen.getByRole("button", { name: "Créer mon espace" }));

    await waitFor(() => {
      expect(screen.getByText("Cockpit privé")).toBeInTheDocument();
    });

    expect(authApi.me).toHaveBeenCalledTimes(1);
    expect(authApi.login).not.toHaveBeenCalled();
  });

  it("succès, session_active:false → confirmation honnête + « Se connecter », aucun second POST d'inscription ni de connexion", async () => {
    const user = userEvent.setup();
    vi.mocked(inscriptionApi.inscrire).mockResolvedValue(reponseSucces(false));

    renderInscriptionPage();
    await avancerJusquaVerification(user);

    await user.click(screen.getByRole("button", { name: "Créer mon espace" }));

    expect(await screen.findByRole("heading", { name: "Votre espace est créé" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Se connecter" })).toHaveAttribute("href", "/login");

    expect(inscriptionApi.inscrire).toHaveBeenCalledTimes(1);
    expect(authApi.login).not.toHaveBeenCalled();
    expect(authApi.me).not.toHaveBeenCalled();
  });

  it("MUTATION-CIBLE 2 — si session_active est retiré du branchement, le test de confirmation honnête devient significatif (session_active:true traité comme :false)", async () => {
    // Ce test documente le COMPORTEMENT ATTENDU exercé par la mutation
    // négative n°2 du rapport (§16/§28) : en l'absence du branchement sur
    // `session_active`, une réponse 201 session_active:true serait traitée
    // comme session_active:false (jamais l'inverse dangereux). Exécuté ici
    // avec le code RÉEL (branchement présent) comme preuve de référence ;
    // la mutation elle-même est appliquée/restaurée manuellement en dehors
    // de la suite automatisée (cf. rapport).
    const user = userEvent.setup();
    vi.mocked(inscriptionApi.inscrire).mockResolvedValue(reponseSucces(true));
    vi.mocked(authApi.me).mockResolvedValue({ utilisateur: UTILISATEUR_MOCK, organisation: ORGANISATION_MOCK });

    renderInscriptionPage();
    await avancerJusquaVerification(user);

    await user.click(screen.getByRole("button", { name: "Créer mon espace" }));

    await waitFor(() => {
      expect(screen.getByText("Cockpit privé")).toBeInTheDocument();
    });
  });

  it("422 (mot de passe) revient à l'étape 1, conserve les saisies", async () => {
    const user = userEvent.setup();
    vi.mocked(inscriptionApi.inscrire).mockRejectedValue(
      erreurAxios(422, { error: "Validation échouée", details: ["Le mot de passe doit contenir au moins 8 caractères."] }),
    );

    renderInscriptionPage();
    await avancerJusquaVerification(user);

    await user.click(screen.getByRole("button", { name: "Créer mon espace" }));

    expect(await screen.findByRole("heading", { name: "Vous" })).toBeInTheDocument();
    expect(screen.getByText("Le mot de passe doit contenir au moins 8 caractères.")).toBeInTheDocument();
    expect(screen.getByLabelText(/^Mot de passe/)).toHaveValue("mot-de-passe-solide");
  });

  it("422 (collision e-mail/SIRET, message déjà sobre) reste à l'étape 3, résumé global, jamais de JSON/SQL brut", async () => {
    const user = userEvent.setup();
    vi.mocked(inscriptionApi.inscrire).mockRejectedValue(
      erreurAxios(422, { error: "Validation échouée", details: ["Cet e-mail ou ce SIRET est déjà utilisé."] }),
    );

    renderInscriptionPage();
    await avancerJusquaVerification(user);

    await user.click(screen.getByRole("button", { name: "Créer mon espace" }));

    const alerte = await screen.findByRole("alert");
    expect(alerte).toHaveTextContent("Cet e-mail ou ce SIRET est déjà utilisé.");
    expect(screen.getByRole("heading", { name: "Vérification" })).toBeInTheDocument();
    expect(document.body.textContent).not.toMatch(/PG::|SQLSTATE|ActiveRecord|constraint/i);
  });

  it("422 (message Rails brut non reconnu) affiche un message générique honnête, jamais l'anglais brut", async () => {
    const user = userEvent.setup();
    vi.mocked(inscriptionApi.inscrire).mockRejectedValue(
      erreurAxios(422, { error: "Validation échouée", details: ["Raison sociale can't be blank"] }),
    );

    renderInscriptionPage();
    await avancerJusquaVerification(user);

    await user.click(screen.getByRole("button", { name: "Créer mon espace" }));

    const alerte = await screen.findByRole("alert");
    expect(alerte).toHaveTextContent("Certaines informations ne sont pas valides. Vérifiez votre saisie.");
    expect(alerte).not.toHaveTextContent(/can't be blank/i);
  });

  it("400 -> message honnête, sans page HTML ni nom de paramètre", async () => {
    const user = userEvent.setup();
    vi.mocked(inscriptionApi.inscrire).mockRejectedValue(erreurAxios(400, { error: "Requête invalide" }));

    renderInscriptionPage();
    await avancerJusquaVerification(user);

    await user.click(screen.getByRole("button", { name: "Créer mon espace" }));

    const alerte = await screen.findByRole("alert");
    expect(alerte).toHaveTextContent("Certaines informations sont incomplètes. Vérifiez le formulaire.");
  });

  it("réseau/5xx -> message honnête, ne prétend jamais que le compte n'existe pas", async () => {
    const user = userEvent.setup();
    vi.mocked(inscriptionApi.inscrire).mockRejectedValue(erreurAxios(500, { error: "Internal Server Error" }));

    renderInscriptionPage();
    await avancerJusquaVerification(user);

    await user.click(screen.getByRole("button", { name: "Créer mon espace" }));

    const alerte = await screen.findByRole("alert");
    expect(alerte).toHaveTextContent(
      "Sereno ne peut pas créer votre espace pour le moment. Réessayez dans quelques instants.",
    );
  });

  it("429 -> respecte Retry-After, désactive la soumission puis la réactive après le délai (fake timers)", async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    const user = userEvent.setup({ delay: null });

    vi.mocked(inscriptionApi.inscrire).mockRejectedValue(
      erreurAxios(429, { error: "Trop de tentatives" }, { "retry-after": "3" }),
    );

    renderInscriptionPage();
    await avancerJusquaVerification(user);

    await user.click(screen.getByRole("button", { name: "Créer mon espace" }));

    const alerte = await screen.findByRole("alert");
    expect(alerte).toHaveTextContent("Trop de tentatives. Patientez un instant avant de réessayer.");

    const bouton = await screen.findByRole("button", { name: /Patientez 3s/ });
    expect(bouton).toBeDisabled();

    await act(async () => {
      await vi.advanceTimersByTimeAsync(1000);
    });
    expect(screen.getByRole("button", { name: /Patientez 2s/ })).toBeDisabled();

    await act(async () => {
      await vi.advanceTimersByTimeAsync(1000);
    });
    expect(screen.getByRole("button", { name: /Patientez 1s/ })).toBeDisabled();

    await act(async () => {
      await vi.advanceTimersByTimeAsync(1000);
    });
    expect(screen.getByRole("button", { name: "Créer mon espace" })).not.toBeDisabled();

    vi.useRealTimers();
  });

  it("aucune double-soumission par touche Entrée : le formulaire d'étape 3 n'a qu'un seul bouton submit", async () => {
    const user = userEvent.setup();
    renderInscriptionPage();
    await avancerJusquaVerification(user);

    const form = screen.getByRole("heading", { name: "Vérification" }).closest("form") as HTMLFormElement;
    const boutonsSubmit = within(form).getAllByRole("button", { name: "Créer mon espace" });
    expect(boutonsSubmit).toHaveLength(1);
    expect(boutonsSubmit[0]).toHaveAttribute("type", "submit");
  });
});

describe("InscriptionPage — aucun appel backend avant l'étape finale", () => {
  it("aucun appel à inscrire() tant que « Créer mon espace » n'a pas été cliqué", async () => {
    const user = userEvent.setup();
    renderInscriptionPage();

    await remplirEtape1(user);
    await user.click(screen.getByRole("button", { name: "Continuer" }));
    await remplirEtape2(user);
    await user.click(screen.getByRole("button", { name: "Continuer" }));

    expect(inscriptionApi.inscrire).not.toHaveBeenCalled();
  });
});

describe("InscriptionPage — OWNER déjà authentifié", () => {
  it("rejoint directement le cockpit, sans jamais voir le formulaire", async () => {
    window.localStorage.setItem("sereno.session.active", "true");
    vi.mocked(authApi.me).mockResolvedValue({ utilisateur: UTILISATEUR_MOCK, organisation: ORGANISATION_MOCK });

    renderInscriptionPage();

    await waitFor(() => {
      expect(screen.getByText("Cockpit privé")).toBeInTheDocument();
    });

    expect(screen.queryByRole("heading", { name: "Vous" })).not.toBeInTheDocument();
  });
});
