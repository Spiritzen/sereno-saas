import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";
import * as destinataireApi from "../api/destinataireApi";
import { DESTINATAIRE_SESSION_MARKER_KEY } from "../api/destinataireHttp";
import { ProtectedDestinataireRoute } from "../components/auth/ProtectedDestinataireRoute";
import { EspaceClientShell } from "../components/layout/EspaceClientShell";
import { DestinataireAuthProvider } from "../context/DestinataireAuthProvider";
import { EspaceClientParametresPage } from "./EspaceClientParametresPage";

vi.mock("../api/destinataireApi");

function renderPage() {
  window.localStorage.setItem(DESTINATAIRE_SESSION_MARKER_KEY, "true");
  vi.mocked(destinataireApi.moi).mockResolvedValue({ email: "client@test.fr", fournisseurs_lies: 1 });

  return render(
    <MemoryRouter initialEntries={["/espace-client/parametres"]}>
      <DestinataireAuthProvider>
        <Routes>
          <Route
            path="/espace-client/parametres"
            element={
              <ProtectedDestinataireRoute>
                <EspaceClientShell>
                  <EspaceClientParametresPage />
                </EspaceClientShell>
              </ProtectedDestinataireRoute>
            }
          />
          <Route path="/espace-client/connexion" element={<div>Page connexion</div>} />
        </Routes>
      </DestinataireAuthProvider>
    </MemoryRouter>,
  );
}

describe("EspaceClientParametresPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    vi.clearAllMocks();
  });

  it("affiche l'e-mail du compte connecté", async () => {
    renderPage();

    const occurrences = await screen.findAllByText("client@test.fr");
    expect(occurrences.length).toBeGreaterThan(0);
  });

  it("supprimer mon compte : demande confirmation, annulable", async () => {
    const user = userEvent.setup();
    renderPage();

    await screen.findAllByText("client@test.fr");

    await user.click(screen.getByRole("button", { name: "Supprimer mon compte" }));
    expect(screen.getByPlaceholderText("Votre mot de passe")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Annuler" }));
    expect(screen.queryByPlaceholderText("Votre mot de passe")).not.toBeInTheDocument();
    expect(destinataireApi.supprimerCompte).not.toHaveBeenCalled();
  });

  it("confirmation avec mot de passe -> supprime le compte, déconnecte et redirige vers connexion", async () => {
    vi.mocked(destinataireApi.supprimerCompte).mockResolvedValue(undefined);
    vi.mocked(destinataireApi.deconnexion).mockResolvedValue(undefined);
    const user = userEvent.setup();

    renderPage();

    await screen.findAllByText("client@test.fr");

    await user.click(screen.getByRole("button", { name: "Supprimer mon compte" }));
    await user.type(screen.getByPlaceholderText("Votre mot de passe"), "motdepasse123");
    await user.click(screen.getByRole("button", { name: "Confirmer la suppression" }));

    expect(await screen.findByText("Page connexion")).toBeInTheDocument();
    expect(destinataireApi.supprimerCompte).toHaveBeenCalledWith("motdepasse123");
  });

  it("mauvais mot de passe -> message d'erreur, compte NON supprimé côté front", async () => {
    vi.mocked(destinataireApi.supprimerCompte).mockRejectedValue({
      response: { data: { error: "Mot de passe invalide" } },
      isAxiosError: true,
    });
    const user = userEvent.setup();

    renderPage();

    await screen.findAllByText("client@test.fr");

    await user.click(screen.getByRole("button", { name: "Supprimer mon compte" }));
    await user.type(screen.getByPlaceholderText("Votre mot de passe"), "mauvais");
    await user.click(screen.getByRole("button", { name: "Confirmer la suppression" }));

    expect(await screen.findByText("Mot de passe invalide")).toBeInTheDocument();
    expect(screen.getAllByText("client@test.fr").length).toBeGreaterThan(0);
  });
});
