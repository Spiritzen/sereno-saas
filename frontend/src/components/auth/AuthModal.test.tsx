import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { afterEach, describe, expect, it, vi } from "vitest";
import * as authApi from "../../api/authApi";
import { AuthProvider } from "../../context/AuthProvider";
import { AuthModal } from "./AuthModal";

vi.mock("../../api/authApi");

function renderModal(open: boolean, onClose = vi.fn()) {
  return render(
    <MemoryRouter initialEntries={["/"]}>
      <AuthProvider>
        <Routes>
          <Route path="/" element={<AuthModal open={open} onClose={onClose} />} />
          <Route path="/app/dashboard" element={<div>Cockpit privé</div>} />
        </Routes>
      </AuthProvider>
    </MemoryRouter>,
  );
}

afterEach(() => {
  window.localStorage.clear();
});

describe("AuthModal", () => {
  it("n'affiche rien quand open=false", () => {
    renderModal(false);

    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });

  it("affiche le même LoginForm que /login (champs identiques)", () => {
    renderModal(true);

    const dialog = screen.getByRole("dialog", { name: "Connexion" });
    expect(within(dialog).getByLabelText("Email")).toBeInTheDocument();
    expect(within(dialog).getByLabelText("Mot de passe")).toBeInTheDocument();
    expect(within(dialog).getByRole("button", { name: "Se connecter" })).toBeInTheDocument();
  });

  it("un échec de connexion garde la modale ouverte, erreur visible", async () => {
    const user = userEvent.setup();
    vi.mocked(authApi.login).mockRejectedValue({
      isAxiosError: true,
      response: { status: 401, data: { error: "Email ou mot de passe invalide" } },
    });

    renderModal(true);

    await user.type(screen.getByLabelText("Email"), "sebastien@test.fr");
    await user.type(screen.getByLabelText("Mot de passe"), "mauvais");
    await user.click(screen.getByRole("button", { name: "Se connecter" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("Email ou mot de passe invalide");
    expect(screen.getByRole("dialog", { name: "Connexion" })).toBeInTheDocument();
  });

  it("un succès de connexion ferme la modale puis navigue vers /app/dashboard", async () => {
    const user = userEvent.setup();
    const onClose = vi.fn();

    vi.mocked(authApi.login).mockResolvedValue({
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

    renderModal(true, onClose);

    await user.type(screen.getByLabelText("Email"), "sebastien@test.fr");
    await user.type(screen.getByLabelText("Mot de passe"), "mot-de-passe-solide");
    await user.click(screen.getByRole("button", { name: "Se connecter" }));

    await waitFor(() => {
      expect(onClose).toHaveBeenCalled();
      expect(screen.getByText("Cockpit privé")).toBeInTheDocument();
    });
  });
});
