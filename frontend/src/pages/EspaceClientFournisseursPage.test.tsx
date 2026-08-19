import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";
import * as destinataireApi from "../api/destinataireApi";
import { DESTINATAIRE_SESSION_MARKER_KEY } from "../api/destinataireHttp";
import { ProtectedDestinataireRoute } from "../components/auth/ProtectedDestinataireRoute";
import { EspaceClientShell } from "../components/layout/EspaceClientShell";
import { DestinataireAuthProvider } from "../context/DestinataireAuthProvider";
import type { EspaceClientFournisseurEntree } from "../types/espaceClient";
import { EspaceClientFournisseursPage } from "./EspaceClientFournisseursPage";

vi.mock("../api/destinataireApi");

const ENTREES: EspaceClientFournisseurEntree[] = [
  { fournisseur: { id: "org-1", raison_sociale: "Atelier Nova", logo_url: null }, nombre_factures: 3 },
  { fournisseur: { id: "org-2", raison_sociale: "Studio Alpha", logo_url: null }, nombre_factures: 1 },
];

function renderPage() {
  window.localStorage.setItem(DESTINATAIRE_SESSION_MARKER_KEY, "true");
  vi.mocked(destinataireApi.moi).mockResolvedValue({ email: "client@test.fr", fournisseurs_lies: 2 });

  return render(
    <MemoryRouter initialEntries={["/espace-client/fournisseurs"]}>
      <DestinataireAuthProvider>
        <Routes>
          <Route
            path="/espace-client/fournisseurs"
            element={
              <ProtectedDestinataireRoute>
                <EspaceClientShell>
                  <EspaceClientFournisseursPage />
                </EspaceClientShell>
              </ProtectedDestinataireRoute>
            }
          />
          <Route path="/espace-client" element={<div>Page liste</div>} />
        </Routes>
      </DestinataireAuthProvider>
    </MemoryRouter>,
  );
}

describe("EspaceClientFournisseursPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    vi.clearAllMocks();
  });

  it("affiche chaque fournisseur avec son nombre de factures", async () => {
    vi.mocked(destinataireApi.listerFournisseurs).mockResolvedValue(ENTREES);

    renderPage();

    expect(await screen.findByText("Atelier Nova")).toBeInTheDocument();
    expect(screen.getByText("3 factures")).toBeInTheDocument();
    expect(screen.getByText("Studio Alpha")).toBeInTheDocument();
    expect(screen.getByText("1 facture")).toBeInTheDocument();
  });

  it("clic sur un fournisseur -> navigue vers la liste filtrée", async () => {
    vi.mocked(destinataireApi.listerFournisseurs).mockResolvedValue(ENTREES);
    const user = userEvent.setup();

    renderPage();

    const lien = await screen.findByRole("link", { name: /Atelier Nova/ });
    expect(lien).toHaveAttribute("href", "/espace-client?fournisseur=org-1");

    await user.click(lien);

    expect(await screen.findByText("Page liste")).toBeInTheDocument();
  });

  it("liste vide -> état vide sobre", async () => {
    vi.mocked(destinataireApi.listerFournisseurs).mockResolvedValue([]);

    renderPage();

    expect(await screen.findByText("Aucun fournisseur pour le moment.")).toBeInTheDocument();
  });

  it("erreur -> état d'erreur avec bouton Réessayer", async () => {
    vi.mocked(destinataireApi.listerFournisseurs)
      .mockRejectedValueOnce({ response: { data: { error: "Erreur serveur" } }, isAxiosError: true })
      .mockResolvedValueOnce(ENTREES);
    const user = userEvent.setup();

    renderPage();

    expect(await screen.findByText("Erreur serveur")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Réessayer" }));

    expect(await screen.findByText("Atelier Nova")).toBeInTheDocument();
  });

  it("401 -> jamais de bandeau d'erreur", async () => {
    vi.mocked(destinataireApi.listerFournisseurs).mockRejectedValue({
      response: { status: 401, data: { error: "Authentification requise" } },
      isAxiosError: true,
    });

    renderPage();

    await waitFor(() => {
      expect(screen.queryByText("Chargement de vos fournisseurs...")).not.toBeInTheDocument();
    });
    expect(screen.queryByText("Authentification requise")).not.toBeInTheDocument();
  });
});
