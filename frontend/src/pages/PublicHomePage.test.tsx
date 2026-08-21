import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { afterEach, describe, expect, it, vi } from "vitest";
import * as authApi from "../api/authApi";
import * as avoirsApi from "../api/avoirsApi";
import * as clientsApi from "../api/clientsApi";
import * as devisApi from "../api/devisApi";
import * as facturesApi from "../api/facturesApi";
import * as paiementsApi from "../api/paiementsApi";
import { AuthProvider } from "../context/AuthProvider";
import { PublicHomePage } from "./PublicHomePage";

// R1.1 (prompt_claude_code_entree_publique_r1_1_correction_humaine.txt §12)
// — zéro mock réseau réel : authApi (pour AuthProvider) ET toutes les API
// métier sont automockées, même patron que R1/DashboardPage.test.tsx. Les
// invariants d'architecture R1 (routage, absence d'API métier, absence de
// données privées, absence de faux CTA d'inscription) sont PRÉSERVÉS
// intégralement ; seuls le contenu et la structure visuelle changent.
vi.mock("../api/authApi");
vi.mock("../api/facturesApi");
vi.mock("../api/clientsApi");
vi.mock("../api/devisApi");
vi.mock("../api/avoirsApi");
vi.mock("../api/paiementsApi");

function renderLanding() {
  return render(
    <MemoryRouter initialEntries={["/"]}>
      <AuthProvider>
        <Routes>
          <Route path="/" element={<PublicHomePage />} />
          <Route path="/login" element={<div>Page de connexion</div>} />
          <Route path="/app/dashboard" element={<div>Cockpit privé</div>} />
        </Routes>
      </AuthProvider>
    </MemoryRouter>,
  );
}

function expectAucunAppelApiMetier() {
  expect(facturesApi.listFactures).not.toHaveBeenCalled();
  expect(clientsApi.listClients).not.toHaveBeenCalled();
  expect(devisApi.listDevis).not.toHaveBeenCalled();
  expect(avoirsApi.listAvoirs).not.toHaveBeenCalled();
  expect(paiementsApi.listPaiements).not.toHaveBeenCalled();
}

afterEach(() => {
  window.localStorage.clear();
});

describe("PublicHomePage — visiteur anonyme", () => {
  it("affiche le H1 public sans être redirigé", () => {
    renderLanding();

    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
      "Facturer devrait être simple.",
    );
    expect(screen.queryByText("Page de connexion")).not.toBeInTheDocument();
    expect(screen.queryByText("Cockpit privé")).not.toBeInTheDocument();
  });

  it("n'appelle aucune API métier (dashboard/factures/clients/devis/avoirs/paiements)", () => {
    renderLanding();

    expectAucunAppelApiMetier();
  });

  it("ne rend aucune identité, donnée d'organisation ni donnée métier privée", () => {
    renderLanding();

    expect(screen.queryByText(/Plan Premium/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/PA connectée/i)).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /déconnexion|se déconnecter/i })).not.toBeInTheDocument();
    expect(screen.queryByText(/Propriétaire/i)).not.toBeInTheDocument();
  });

  it("R3 §11 — le hero ne porte qu'UN seul couple d'actions (« Créer mon espace » + « Se connecter »)", () => {
    renderLanding();

    const hero = document.getElementById("accueil") as HTMLElement;
    const actionsContainer = within(hero).getByRole("link", { name: "Créer mon espace" })
      .parentElement as HTMLElement;

    const links = within(actionsContainer).getAllByRole("link");
    const buttons = within(actionsContainer).getAllByRole("button");

    expect(links).toHaveLength(1);
    expect(links[0]).toHaveTextContent("Créer mon espace");
    expect(links[0]).toHaveAttribute("href", "/inscription");

    expect(buttons).toHaveLength(1);
    expect(buttons[0]).toHaveTextContent("Se connecter");
  });

  it("R3 §15 — le CTA « Créer mon espace » (hero + pied de page) mène vers /inscription", () => {
    renderLanding();

    const inscriptionLinks = screen.getAllByRole("link", { name: "Créer mon espace" });
    expect(inscriptionLinks.length).toBeGreaterThanOrEqual(2); // hero + pied de page

    for (const link of inscriptionLinks) {
      expect(link).toHaveAttribute("href", "/inscription");
    }
  });

  it("R3 §15 — « Se connecter » (hero) et « Connexion » (topbar) ouvrent la modale de connexion, jamais /login", async () => {
    const user = userEvent.setup();
    renderLanding();

    expect(screen.queryByRole("link", { name: "Se connecter" })).not.toBeInTheDocument();
    expect(screen.queryByRole("link", { name: "Connexion" })).not.toBeInTheDocument();

    const hero = document.getElementById("accueil") as HTMLElement;
    await user.click(within(hero).getByRole("button", { name: "Se connecter" }));

    const dialog = screen.getByRole("dialog", { name: "Connexion" });
    expect(dialog).toBeInTheDocument();
    expect(screen.queryByText("Page de connexion")).not.toBeInTheDocument();
  });

  it("R1.1 §6.3 — la topbar ne duplique jamais « Découvrir Sereno »", () => {
    renderLanding();

    expect(screen.queryByText(/Découvrir Sereno/i)).not.toBeInTheDocument();
  });

  it("R1.1 §7 — la grande scène produit montre les 4 étapes d'un même parcours (Créer/Vérifier/Envoyer/Suivre)", () => {
    renderLanding();

    const hero = document.getElementById("accueil") as HTMLElement;
    expect(within(hero).getByText("Créer")).toBeInTheDocument();
    expect(within(hero).getByText("Vérifier")).toBeInTheDocument();
    expect(within(hero).getByText("Envoyer")).toBeInTheDocument();
    expect(within(hero).getByText("Suivre")).toBeInTheDocument();
    expect(within(hero).getByText("Prête à vérifier")).toBeInTheDocument();
    expect(within(hero).getByText("Facture de démonstration")).toBeInTheDocument();
  });

  it("R1.1 §8.1 — le bloc « Comment ça marche » présente un seul chemin en 4 étapes, jamais des cartes clonées", () => {
    renderLanding();

    const section = document.getElementById("comment-ca-marche") as HTMLElement;
    expect(within(section).getByText("Créez")).toBeInTheDocument();
    expect(within(section).getByText("Vérifiez")).toBeInTheDocument();
    expect(within(section).getByText("Envoyez")).toBeInTheDocument();
    expect(within(section).getByText("Suivez")).toBeInTheDocument();
  });

  it("R1.1 §8.2 — le bloc « Pourquoi Sereno » présente les 3 bénéfices humains", () => {
    renderLanding();

    const section = document.getElementById("pourquoi-sereno") as HTMLElement;
    expect(within(section).getByText("Moins de doutes")).toBeInTheDocument();
    expect(within(section).getByText("Moins d’oublis")).toBeInTheDocument();
    expect(within(section).getByText("Plus de temps pour votre métier")).toBeInTheDocument();
  });

  it("R1.1 §8.3 — le bloc « Vos données » présente les 3 preuves de confiance", () => {
    renderLanding();

    const section = document.getElementById("vos-donnees") as HTMLElement;
    expect(within(section).getByText("Un espace séparé pour chaque entreprise")).toBeInTheDocument();
    expect(
      within(section).getByText("Votre mot de passe n'est jamais conservé tel quel"),
    ).toBeInTheDocument();
    expect(within(section).getByText("Des contrôles utiles avant l'envoi")).toBeInTheDocument();
  });

  it("les ancres de la sidebar publique correspondent à des sections réellement présentes", () => {
    const { container } = renderLanding();

    const nav = screen.getByRole("navigation", { name: "Sections de la page" });
    const links = within(nav).getAllByRole("link");

    expect(links.length).toBeGreaterThan(0);

    for (const link of links) {
      const href = link.getAttribute("href");
      expect(href).toMatch(/^#/);

      const targetId = href!.slice(1);
      expect(container.querySelector(`#${targetId}`)).not.toBeNull();
    }
  });

  it("aucun CTA actif « Créer un compte » ne mène vers une route inexistante", () => {
    renderLanding();

    expect(screen.queryByRole("link", { name: /créer un compte/i })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /créer un compte/i })).not.toBeInTheDocument();
  });
});

describe("PublicHomePage — OWNER déjà authentifié", () => {
  it("est redirigé vers /app/dashboard, sans jamais voir la landing", async () => {
    window.localStorage.setItem("sereno.session.active", "true");
    vi.mocked(authApi.me).mockResolvedValue({
      utilisateur: {
        id: "u1",
        email: "sebastien@test.fr",
        nom: "Cantrelle",
        prenom: "Sébastien",
        role: "owner",
        actif: true,
      },
      organisation: {
        id: "o1",
        raison_sociale: "Studio Démo",
        siret: "12345678900000",
        regime_tva: "reel",
      },
    });

    renderLanding();

    await waitFor(() => {
      expect(screen.getByText("Cockpit privé")).toBeInTheDocument();
    });

    expect(
      screen.queryByRole("heading", { level: 1, name: "Facturer devrait être simple." }),
    ).not.toBeInTheDocument();
  });
});
