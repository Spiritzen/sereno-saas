import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";
import * as destinataireApi from "../api/destinataireApi";
import { DestinataireAuthProvider } from "../context/DestinataireAuthProvider";
import { EspaceClientConnexionPage } from "./EspaceClientConnexionPage";

vi.mock("../api/destinataireApi");

function renderPage() {
  return render(
    <MemoryRouter initialEntries={["/espace-client/connexion"]}>
      <DestinataireAuthProvider>
        <Routes>
          <Route path="/espace-client/connexion" element={<EspaceClientConnexionPage />} />
          <Route path="/espace-client" element={<div>Placeholder accueil</div>} />
        </Routes>
      </DestinataireAuthProvider>
    </MemoryRouter>,
  );
}

describe("EspaceClientConnexionPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    vi.clearAllMocks();
  });

  it("succès -> navigue vers le placeholder /espace-client", async () => {
    const user = userEvent.setup();
    vi.mocked(destinataireApi.connexion).mockResolvedValue({ email: "x@test.fr", fournisseurs_lies: 1 });

    renderPage();

    await user.type(screen.getByPlaceholderText("Votre email"), "x@test.fr");
    await user.type(screen.getByPlaceholderText("Votre mot de passe"), "motdepasse123");
    await user.click(screen.getByRole("button", { name: "Se connecter" }));

    expect(await screen.findByText("Placeholder accueil")).toBeInTheDocument();
    expect(destinataireApi.connexion).toHaveBeenCalledWith({
      email: "x@test.fr",
      mot_de_passe: "motdepasse123",
    });
  });

  it("échec -> message GÉNÉRIQUE affiché tel quel, reste sur la page", async () => {
    const user = userEvent.setup();
    vi.mocked(destinataireApi.connexion).mockRejectedValue({
      response: { data: { error: "E-mail ou mot de passe invalide" } },
      isAxiosError: true,
    });

    renderPage();

    await user.type(screen.getByPlaceholderText("Votre email"), "x@test.fr");
    await user.type(screen.getByPlaceholderText("Votre mot de passe"), "mauvais");
    await user.click(screen.getByRole("button", { name: "Se connecter" }));

    expect(await screen.findByText("E-mail ou mot de passe invalide")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Se connecter" })).toBeInTheDocument();
  });
});
