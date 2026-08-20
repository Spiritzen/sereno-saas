import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";
import * as authApi from "../../api/authApi";
import { AuthProvider } from "../../context/AuthProvider";
import { AppShell } from "./AppShell";

vi.mock("../../api/authApi");

function renderShell(initialEntry = "/app/dashboard") {
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

  return render(
    <MemoryRouter initialEntries={[initialEntry]}>
      <AuthProvider>
        <Routes>
          <Route
            path="/app/dashboard"
            element={
              <AppShell>
                <div>Contenu dashboard</div>
              </AppShell>
            }
          />
          <Route
            path="/app/factures"
            element={
              <AppShell>
                <div>Contenu factures</div>
              </AppShell>
            }
          />
        </Routes>
      </AuthProvider>
    </MemoryRouter>,
  );
}

describe("AppShell", () => {
  beforeEach(() => {
    window.localStorage.clear();
    vi.clearAllMocks();
  });

  it("D0 §1 — le contenu de la page ET la sidebar se rendent sans erreur (Dashboard)", async () => {
    renderShell("/app/dashboard");

    expect(await screen.findByText("Contenu dashboard")).toBeInTheDocument();
    expect(screen.getAllByText("Dashboard").length).toBeGreaterThan(0);
  });

  it("D0 §1 — même shell, non-régression sur une autre page (Factures)", async () => {
    renderShell("/app/factures");

    expect(await screen.findByText("Contenu factures")).toBeInTheDocument();
    expect(screen.getAllByText("Factures").length).toBeGreaterThan(0);
  });

  it("D0 §3 — le hamburger ouvre le tiroir mobile avec la nav complète", async () => {
    const user = userEvent.setup();
    renderShell();

    await screen.findByText("Contenu dashboard");

    await user.click(screen.getByRole("button", { name: "Ouvrir le menu" }));

    const drawer = screen.getByRole("dialog", { name: "Navigation" });
    expect(drawer).toBeInTheDocument();
    // La sidebar reprise dans le tiroir est TOUJOURS déployée (forceExpanded).
    expect(screen.getAllByText("Dashboard").length).toBeGreaterThan(1);
  });

  it("D0 §3 — un clic sur une entrée du tiroir ferme le tiroir (navigation)", async () => {
    const user = userEvent.setup();
    renderShell("/app/dashboard");

    await screen.findByText("Contenu dashboard");
    await user.click(screen.getByRole("button", { name: "Ouvrir le menu" }));
    expect(screen.getByRole("dialog", { name: "Navigation" })).toBeInTheDocument();

    const drawer = screen.getByRole("dialog", { name: "Navigation" });
    const facturesLinks = screen.getAllByRole("link", { name: /Factures/ });
    const lienDansLeTiroir = facturesLinks.find((link) => drawer.contains(link));
    expect(lienDansLeTiroir).toBeDefined();

    await user.click(lienDansLeTiroir as HTMLElement);

    expect(await screen.findByText("Contenu factures")).toBeInTheDocument();
    expect(screen.queryByRole("dialog", { name: "Navigation" })).not.toBeInTheDocument();
  });

  it("D0 §3 — Échap ferme le tiroir", async () => {
    const user = userEvent.setup();
    renderShell();

    await screen.findByText("Contenu dashboard");
    await user.click(screen.getByRole("button", { name: "Ouvrir le menu" }));
    expect(screen.getByRole("dialog", { name: "Navigation" })).toBeInTheDocument();

    await user.keyboard("{Escape}");

    expect(screen.queryByRole("dialog", { name: "Navigation" })).not.toBeInTheDocument();
  });

  it("§6.5 reprise — le hamburger porte aria-expanded/aria-controls, à jour à l'ouverture", async () => {
    const user = userEvent.setup();
    renderShell();

    await screen.findByText("Contenu dashboard");

    const hamburger = screen.getByRole("button", { name: "Ouvrir le menu" });
    expect(hamburger).toHaveAttribute("aria-expanded", "false");
    expect(hamburger).toHaveAttribute("aria-controls");

    await user.click(hamburger);

    expect(hamburger).toHaveAttribute("aria-expanded", "true");
    const controlsId = hamburger.getAttribute("aria-controls");
    expect(document.getElementById(controlsId as string)).toBeInTheDocument();
  });

  it("§6.4 reprise — aucun doublon de marque Topbar/Sidebar (identité SEULEMENT en sidebar)", async () => {
    renderShell();

    await screen.findByText("Contenu dashboard");

    expect(screen.getAllByText("Sereno")).toHaveLength(1);
  });

  it("§4.3/§7 reprise — aucun contrôle fictif recherche/notification/PA/abonnement", async () => {
    renderShell();

    await screen.findByText("Contenu dashboard");

    expect(screen.queryByPlaceholderText(/rechercher/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/PA connectée/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Plan Premium/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/% utilisé/i)).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /notification/i })).not.toBeInTheDocument();
  });

  it("§6.2 reprise — les routes de l'espace client n'apparaissent JAMAIS dans la sidebar app", async () => {
    renderShell();

    await screen.findByText("Contenu dashboard");

    expect(screen.queryByText("Mes factures")).not.toBeInTheDocument();
    expect(screen.queryByText("Mes fournisseurs")).not.toBeInTheDocument();
  });

  it("D0.1 Correction B — le profil utilisateur n'est rendu qu'UNE seule fois (tiroir fermé)", async () => {
    renderShell();

    await screen.findByText("Contenu dashboard");

    expect(screen.getAllByText("Sébastien Cantrelle")).toHaveLength(1);
    expect(screen.getAllByRole("button", { name: "Se déconnecter" })).toHaveLength(1);
  });

  it("D0.1 Correction A — Sidebar/Topbar/main sont des enfants DIRECTS de .sereno-frame (plus de second shell imbriqué)", async () => {
    const { container } = renderShell();

    await screen.findByText("Contenu dashboard");

    const frame = container.querySelector(".sereno-frame") as HTMLElement;
    expect(frame).toBeInTheDocument();
    expect(frame.querySelector(".sereno-body")).not.toBeInTheDocument();

    const directChildClasses = Array.from(frame.children).map((el) => el.className);
    expect(directChildClasses.some((c) => c.includes("sidebar"))).toBe(true);
    expect(directChildClasses.some((c) => c.includes("topbar"))).toBe(true);
    expect(directChildClasses.some((c) => c === "main")).toBe(true);
  });

  it("D0.1 Correction B — la Topbar de l'app porte le modificateur masqué sur desktop", async () => {
    const { container } = renderShell();

    await screen.findByText("Contenu dashboard");

    const topbar = container.querySelector("header.topbar");
    expect(topbar).toHaveClass("topbar--app");
  });
});
