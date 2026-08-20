import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { describe, expect, it } from "vitest";
import { PublicShell } from "./PublicShell";

// R1.1 (prompt_claude_code_entree_publique_r1_1_correction_humaine.txt §12)
// — même patron d'interaction que R1/AppShell.test.tsx pour le tiroir mobile
// (MobileNavDrawer réutilisé tel quel) ; adapté aux nouveaux intitulés de
// navigation orientés bénéfice et à la topbar à une seule action.
function renderShell() {
  return render(
    <MemoryRouter>
      <PublicShell>
        <div id="accueil">Accueil</div>
        <div id="comment-ca-marche">Comment ça marche</div>
      </PublicShell>
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

  it("R1.1 §6.2 — offre un accès discret « Se connecter » en pied de sidebar", () => {
    renderShell();

    const sidebar = screen.getByRole("complementary", { name: "Navigation publique" });
    const loginLinks = within(sidebar).getAllByRole("link", { name: "Se connecter" });
    expect(loginLinks.length).toBe(1);
    expect(loginLinks[0]).toHaveAttribute("href", "/login");
  });

  it("R1.1 §6.3 — la topbar ne porte qu'UNE seule action (« Connexion »), jamais « Découvrir Sereno »", () => {
    renderShell();

    const topbar = screen.getByRole("banner");
    const actionLinks = within(topbar).getAllByRole("link");
    expect(actionLinks).toHaveLength(1);
    expect(actionLinks[0]).toHaveTextContent("Connexion");
    expect(actionLinks[0]).toHaveAttribute("href", "/login");

    expect(screen.queryByText(/Découvrir Sereno/i)).not.toBeInTheDocument();
  });

  it("le hamburger ouvre le tiroir mobile avec la même navigation, accessible", async () => {
    const user = userEvent.setup();
    renderShell();

    await user.click(screen.getByRole("button", { name: "Ouvrir le menu" }));

    const drawer = screen.getByRole("dialog", { name: "Navigation publique" });
    expect(drawer).toBeInTheDocument();
    expect(within(drawer).getByRole("link", { name: "Accueil" })).toHaveAttribute("href", "#accueil");
    expect(within(drawer).getByRole("link", { name: "Se connecter" })).toHaveAttribute("href", "/login");
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
});
