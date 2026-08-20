import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";
import * as destinataireApi from "../../api/destinataireApi";
import { DESTINATAIRE_SESSION_MARKER_KEY } from "../../api/destinataireHttp";
import { DestinataireAuthProvider } from "../../context/DestinataireAuthProvider";
import { EspaceClientShell } from "./EspaceClientShell";

vi.mock("../../api/destinataireApi");

function renderShell() {
  window.localStorage.setItem(DESTINATAIRE_SESSION_MARKER_KEY, "true");
  vi.mocked(destinataireApi.moi).mockResolvedValue({ email: "client@test.fr", fournisseurs_lies: 1 });

  return render(
    <MemoryRouter initialEntries={["/espace-client"]}>
      <DestinataireAuthProvider>
        <Routes>
          <Route
            path="/espace-client"
            element={
              <EspaceClientShell>
                <div>Contenu de la page</div>
              </EspaceClientShell>
            }
          />
          <Route path="/espace-client/connexion" element={<div>Page connexion</div>} />
          <Route
            path="/espace-client/fournisseurs"
            element={
              <EspaceClientShell>
                <div>Contenu fournisseurs</div>
              </EspaceClientShell>
            }
          />
        </Routes>
      </DestinataireAuthProvider>
    </MemoryRouter>,
  );
}

describe("EspaceClientShell", () => {
  beforeEach(() => {
    window.localStorage.clear();
    vi.clearAllMocks();
  });

  it("affiche le conteneur centré (jumeau AppShell) avec le contenu, la marque et le compte", async () => {
    renderShell();

    expect(await screen.findByText("Contenu de la page")).toBeInTheDocument();
    expect(screen.getByText("Espace client")).toBeInTheDocument();
    expect(await screen.findByText("client@test.fr")).toBeInTheDocument();
  });

  it("§2 sidebar dédiée : Mes factures / Mes fournisseurs / Paramètres, rétractable", async () => {
    const user = userEvent.setup();
    renderShell();

    await screen.findByText("Contenu de la page");

    expect(screen.getByRole("link", { name: /Mes factures/ })).toHaveAttribute(
      "href",
      "/espace-client",
    );
    expect(screen.getByRole("link", { name: /Mes fournisseurs/ })).toHaveAttribute(
      "href",
      "/espace-client/fournisseurs",
    );
    expect(screen.getByRole("link", { name: /Paramètres/ })).toHaveAttribute(
      "href",
      "/espace-client/parametres",
    );

    const toggle = screen.getByRole("button", { name: "Développer le menu" });
    await user.click(toggle);
    expect(screen.getByRole("button", { name: "Réduire le menu" })).toBeInTheDocument();
  });

  it("D0 §3 execution_dashboard_d0_squelette.txt — hamburger mobile ouvre le tiroir, clic sur une entrée le ferme", async () => {
    const user = userEvent.setup();
    renderShell();

    await screen.findByText("Contenu de la page");

    await user.click(screen.getByRole("button", { name: "Ouvrir le menu" }));

    const drawer = screen.getByRole("dialog", { name: "Navigation espace client" });
    expect(drawer).toBeInTheDocument();

    const liensFournisseurs = screen.getAllByRole("link", { name: /Mes fournisseurs/ });
    const lienDansLeTiroir = liensFournisseurs.find((link) => drawer.contains(link));
    expect(lienDansLeTiroir).toBeDefined();

    await user.click(lienDansLeTiroir as HTMLElement);

    expect(await screen.findByText("Contenu fournisseurs")).toBeInTheDocument();
    expect(screen.queryByRole("dialog", { name: "Navigation espace client" })).not.toBeInTheDocument();
  });

  it("§6.5 reprise — le hamburger espace client porte aria-expanded/aria-controls, à jour à l'ouverture", async () => {
    const user = userEvent.setup();
    renderShell();

    await screen.findByText("Contenu de la page");

    const hamburger = screen.getByRole("button", { name: "Ouvrir le menu" });
    expect(hamburger).toHaveAttribute("aria-expanded", "false");
    expect(hamburger).toHaveAttribute("aria-controls");

    await user.click(hamburger);

    expect(hamburger).toHaveAttribute("aria-expanded", "true");
    const controlsId = hamburger.getAttribute("aria-controls");
    expect(document.getElementById(controlsId as string)).toBeInTheDocument();
  });

  it("§4.3/§7 reprise — aucun contrôle fictif, et aucune route de l'app propriétaire", async () => {
    renderShell();

    await screen.findByText("Contenu de la page");

    expect(screen.queryByPlaceholderText(/rechercher/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/PA connectée/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Plan Premium/i)).not.toBeInTheDocument();
    expect(screen.queryByText("Dashboard")).not.toBeInTheDocument();
    expect(screen.queryByText("Clients")).not.toBeInTheDocument();
  });

  it("bouton de déconnexion -> appelle deconnexion et redirige vers connexion", async () => {
    vi.mocked(destinataireApi.deconnexion).mockResolvedValue(undefined);
    const user = userEvent.setup();

    renderShell();

    await screen.findByText("Contenu de la page");

    await user.click(screen.getByRole("button", { name: /Se déconnecter/i }));

    expect(await screen.findByText("Page connexion")).toBeInTheDocument();
    expect(destinataireApi.deconnexion).toHaveBeenCalled();
  });
});
