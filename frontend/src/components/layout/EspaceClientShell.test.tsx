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
