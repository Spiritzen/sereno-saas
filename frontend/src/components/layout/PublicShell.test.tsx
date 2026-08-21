import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { describe, expect, it, vi } from "vitest";
import * as authApi from "../../api/authApi";
import { AuthProvider } from "../../context/AuthProvider";
import { PublicShell } from "./PublicShell";

// R1.1 (prompt_claude_code_entree_publique_r1_1_correction_humaine.txt §12)
// — même patron d'interaction que R1/AppShell.test.tsx pour le tiroir mobile
// (MobileNavDrawer réutilisé tel quel) ; adapté aux nouveaux intitulés de
// navigation orientés bénéfice et à la topbar à une seule action.
//
// R3 (prompt_claude_code_inscription_owner_frontend_r3.txt §10/§11) —
// « Connexion »/« Se connecter » ouvrent désormais une modale (AuthModal)
// au lieu de naviguer vers /login : AuthModal composant LoginForm, qui
// appelle useAuth(), PublicShell doit donc toujours être enveloppé dans
// AuthProvider (authApi automocké, même patron que PublicHomePage.test.tsx)
// — y compris quand la modale reste fermée, pour couvrir les tests qui
// l'ouvrent.
vi.mock("../../api/authApi");

function renderShell(initialPath = "/") {
  return render(
    <MemoryRouter initialEntries={[initialPath]}>
      <AuthProvider>
        <PublicShell>
          <div id="accueil">Accueil</div>
          <div id="comment-ca-marche">Comment ça marche</div>
        </PublicShell>
      </AuthProvider>
    </MemoryRouter>,
  );
}

describe("PublicShell", () => {
  it("rend la sidebar publique desktop avec la navigation par ancres, sans identité privée", () => {
    renderShell();

    const sidebar = screen.getByRole("complementary", { name: "Navigation publique" });
    expect(within(sidebar).getByText("Sereno")).toBeInTheDocument();

    const nav = within(sidebar).getByRole("navigation", { name: "Sections de la page" });
    expect(within(nav).getByRole("link", { name: "Accueil" })).toHaveAttribute("href", "#accueil");
    expect(within(nav).getByRole("link", { name: "Comment ça marche" })).toHaveAttribute(
      "href",
      "#comment-ca-marche",
    );
    expect(within(nav).getByRole("link", { name: "Vos données" })).toHaveAttribute(
      "href",
      "#vos-donnees",
    );
    expect(within(nav).getByRole("link", { name: "Pourquoi Sereno" })).toHaveAttribute(
      "href",
      "#pourquoi-sereno",
    );

    expect(screen.queryByRole("button", { name: /déconnexion|se déconnecter/i })).not.toBeInTheDocument();
    expect(screen.queryByText(/Plan Premium/i)).not.toBeInTheDocument();
  });

  it("R1.1 §6.2 — affiche le bloc de réassurance humain, jamais un calendrier ou un abonnement fictif", () => {
    renderShell();

    const sidebar = screen.getByRole("complementary", { name: "Navigation publique" });
    expect(within(sidebar).getByText("Conçu pour vous guider")).toBeInTheDocument();
    expect(screen.queryByText(/Plan Premium/i)).not.toBeInTheDocument();
    expect(screen.queryByRole("grid")).not.toBeInTheDocument(); // aucun calendrier
  });

  it("R3 §11 — offre « Créer mon espace » (route dédiée) en pied de sidebar", () => {
    renderShell();

    const sidebar = screen.getByRole("complementary", { name: "Navigation publique" });
    const ctaLinks = within(sidebar).getAllByRole("link", { name: "Créer mon espace" });
    expect(ctaLinks.length).toBe(1);
    expect(ctaLinks[0]).toHaveAttribute("href", "/inscription");
  });

  it("R3 §10 — « Se connecter » (sidebar) est un bouton qui ouvre la modale, jamais un lien /login", () => {
    renderShell();

    const sidebar = screen.getByRole("complementary", { name: "Navigation publique" });
    const loginButtons = within(sidebar).getAllByRole("button", { name: "Se connecter" });
    expect(loginButtons.length).toBe(1);

    expect(screen.queryByRole("link", { name: "Se connecter" })).not.toBeInTheDocument();
  });

  it("R3 §10 — la topbar ne porte qu'UNE seule action visible (« Connexion », un bouton, jamais un lien), toujours pas « Découvrir Sereno »", () => {
    renderShell();

    const topbar = screen.getByRole("banner");
    expect(within(topbar).queryAllByRole("link")).toHaveLength(0);

    const connexionButton = within(topbar).getByRole("button", { name: "Connexion" });
    expect(connexionButton).toBeInTheDocument();

    expect(screen.queryByText(/Découvrir Sereno/i)).not.toBeInTheDocument();
  });

  it("R3 §10 — cliquer sur « Connexion » (topbar) ouvre la modale de connexion accessible", async () => {
    const user = userEvent.setup();
    renderShell();

    expect(screen.queryByRole("dialog", { name: "Connexion" })).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Connexion" }));

    const dialog = screen.getByRole("dialog", { name: "Connexion" });
    expect(dialog).toBeInTheDocument();
    expect(within(dialog).getByRole("button", { name: "Se connecter" })).toBeInTheDocument();
  });

  it("R3 §10 — Échap ferme la modale de connexion", async () => {
    const user = userEvent.setup();
    renderShell();

    await user.click(screen.getByRole("button", { name: "Connexion" }));
    expect(screen.getByRole("dialog", { name: "Connexion" })).toBeInTheDocument();

    await user.keyboard("{Escape}");

    expect(screen.queryByRole("dialog", { name: "Connexion" })).not.toBeInTheDocument();
  });

  it("le hamburger ouvre le tiroir mobile avec la même navigation, accessible", async () => {
    const user = userEvent.setup();
    renderShell();

    await user.click(screen.getByRole("button", { name: "Ouvrir le menu" }));

    const drawer = screen.getByRole("dialog", { name: "Navigation publique" });
    expect(drawer).toBeInTheDocument();
    expect(within(drawer).getByRole("link", { name: "Accueil" })).toHaveAttribute("href", "#accueil");
    expect(within(drawer).getByRole("link", { name: "Créer mon espace" })).toHaveAttribute(
      "href",
      "/inscription",
    );
    expect(within(drawer).getByRole("button", { name: "Se connecter" })).toBeInTheDocument();
  });

  it("R3 §10 — dans le tiroir mobile, « Se connecter » ferme le tiroir puis ouvre la modale", async () => {
    const user = userEvent.setup();
    renderShell();

    await user.click(screen.getByRole("button", { name: "Ouvrir le menu" }));
    const drawer = screen.getByRole("dialog", { name: "Navigation publique" });

    await user.click(within(drawer).getByRole("button", { name: "Se connecter" }));

    expect(screen.queryByRole("dialog", { name: "Navigation publique" })).not.toBeInTheDocument();
    expect(screen.getByRole("dialog", { name: "Connexion" })).toBeInTheDocument();
  });

  it("Échap ferme le tiroir et restaure le focus sur le bouton hamburger", async () => {
    const user = userEvent.setup();
    renderShell();

    const hamburger = screen.getByRole("button", { name: "Ouvrir le menu" });
    await user.click(hamburger);
    expect(screen.getByRole("dialog", { name: "Navigation publique" })).toBeInTheDocument();

    await user.keyboard("{Escape}");

    expect(screen.queryByRole("dialog", { name: "Navigation publique" })).not.toBeInTheDocument();
    expect(hamburger).toHaveFocus();
  });

  it("un clic sur une ancre du tiroir referme le tiroir", async () => {
    const user = userEvent.setup();
    renderShell();

    await user.click(screen.getByRole("button", { name: "Ouvrir le menu" }));
    const drawer = screen.getByRole("dialog", { name: "Navigation publique" });

    await user.click(within(drawer).getByRole("link", { name: "Comment ça marche" }));

    expect(screen.queryByRole("dialog", { name: "Navigation publique" })).not.toBeInTheDocument();
  });

  it("le bouton hamburger porte aria-expanded/aria-controls, à jour à l'ouverture", async () => {
    const user = userEvent.setup();
    renderShell();

    const hamburger = screen.getByRole("button", { name: "Ouvrir le menu" });
    expect(hamburger).toHaveAttribute("aria-expanded", "false");
    expect(hamburger).toHaveAttribute("aria-controls");

    await user.click(hamburger);

    expect(hamburger).toHaveAttribute("aria-expanded", "true");
    const controlsId = hamburger.getAttribute("aria-controls");
    expect(document.getElementById(controlsId as string)).toBeInTheDocument();
  });

  describe("R3 §11 — remplacement des CTA pour un OWNER déjà authentifié", () => {
    // Mécanisme défensif du shell partagé : dans l'usage RÉEL actuel,
    // PublicHomePage et InscriptionPage redirigent toutes deux un OWNER
    // authentifié AVANT de monter PublicShell (décision confirmée du
    // 21/08/2026, cf. commentaire en tête de PublicShell.tsx) — ce test
    // monte donc PublicShell DIRECTEMENT, sans page englobante, pour prouver
    // que le mécanisme lui-même reste honnête si un futur consommateur
    // omettait sa propre garde.
    async function renderShellAuthentifie() {
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
          regime_tva: "reel_normal",
        },
      });

      const utils = renderShell();
      await screen.findAllByRole("link", { name: "Ouvrir mon cockpit" });

      return utils;
    }

    it("remplace « Créer mon espace »/« Se connecter » (sidebar) par un unique « Ouvrir mon cockpit »", async () => {
      await renderShellAuthentifie();

      const sidebar = screen.getByRole("complementary", { name: "Navigation publique" });
      const cockpitLinks = within(sidebar).getAllByRole("link", { name: "Ouvrir mon cockpit" });
      expect(cockpitLinks).toHaveLength(1);
      expect(cockpitLinks[0]).toHaveAttribute("href", "/app/dashboard");

      expect(within(sidebar).queryByRole("link", { name: "Créer mon espace" })).not.toBeInTheDocument();
      expect(within(sidebar).queryByRole("button", { name: "Se connecter" })).not.toBeInTheDocument();
    });

    it("remplace « Connexion » (topbar) par « Ouvrir mon cockpit »", async () => {
      await renderShellAuthentifie();

      const topbar = screen.getByRole("banner");
      expect(within(topbar).getByRole("link", { name: "Ouvrir mon cockpit" })).toHaveAttribute(
        "href",
        "/app/dashboard",
      );
      expect(within(topbar).queryByRole("button", { name: "Connexion" })).not.toBeInTheDocument();
    });
  });

  describe("nav par ancres route-aware (hors page d'accueil)", () => {
    it("sur une autre page publique (ex. /inscription), les ancres deviennent des liens vers / plutôt que des ancres mortes", () => {
      renderShell("/inscription");

      const sidebar = screen.getByRole("complementary", { name: "Navigation publique" });
      const nav = within(sidebar).getByRole("navigation", { name: "Sections de la page" });

      expect(within(nav).getByRole("link", { name: "Accueil" })).toHaveAttribute("href", "/#accueil");
      expect(within(nav).getByRole("link", { name: "Comment ça marche" })).toHaveAttribute(
        "href",
        "/#comment-ca-marche",
      );
    });
  });
});
