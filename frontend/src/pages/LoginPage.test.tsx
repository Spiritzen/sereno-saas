import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { afterEach, describe, expect, it, vi } from "vitest";
import * as authApi from "../api/authApi";
import { AuthProvider } from "../context/AuthProvider";
import { LoginPage } from "./LoginPage";

// R3 (prompt_claude_code_inscription_owner_frontend_r3.txt §15) — /login
// reste une route publique fonctionnelle de secours et de deep-link : même
// comportement qu'avant l'extraction de LoginForm, prouvé directement ici
// (aucun test dédié n'existait pour cette page avant R3).
vi.mock("../api/authApi");

function renderLoginPage() {
  return render(
    <MemoryRouter initialEntries={["/login"]}>
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/app/dashboard" element={<div>Cockpit privé</div>} />
        </Routes>
      </AuthProvider>
    </MemoryRouter>,
  );
}

afterEach(() => {
  window.localStorage.clear();
});

describe("LoginPage", () => {
  it("affiche le formulaire de connexion (LoginForm) dans son habillage de page dédiée", () => {
    renderLoginPage();

    expect(screen.getByRole("heading", { level: 1, name: "Connexion" })).toBeInTheDocument();
    expect(screen.getByLabelText("Email")).toBeInTheDocument();
    expect(screen.getByLabelText("Mot de passe")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Se connecter" })).toBeInTheDocument();
  });

  it("une connexion réussie navigue vers /app/dashboard", async () => {
    const user = userEvent.setup();
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

    renderLoginPage();

    await user.type(screen.getByLabelText("Email"), "sebastien@test.fr");
    await user.type(screen.getByLabelText("Mot de passe"), "mot-de-passe-solide");
    await user.click(screen.getByRole("button", { name: "Se connecter" }));

    await waitFor(() => {
      expect(screen.getByText("Cockpit privé")).toBeInTheDocument();
    });
  });

  it("un échec de connexion affiche l'erreur sans naviguer", async () => {
    const user = userEvent.setup();
    vi.mocked(authApi.login).mockRejectedValue({
      isAxiosError: true,
      response: { status: 401, data: { error: "Email ou mot de passe invalide" } },
    });

    renderLoginPage();

    await user.type(screen.getByLabelText("Email"), "sebastien@test.fr");
    await user.type(screen.getByLabelText("Mot de passe"), "mauvais-mot-de-passe");
    await user.click(screen.getByRole("button", { name: "Se connecter" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("Email ou mot de passe invalide");
    expect(screen.queryByText("Cockpit privé")).not.toBeInTheDocument();
  });

  it("une erreur Axios sans response affiche le message réseau, jamais \"undefined\"", async () => {
    const user = userEvent.setup();
    vi.mocked(authApi.login).mockRejectedValue({
      isAxiosError: true,
      response: undefined,
    });

    renderLoginPage();

    await user.type(screen.getByLabelText("Email"), "sebastien@test.fr");
    await user.type(screen.getByLabelText("Mot de passe"), "mot-de-passe-solide");
    await user.click(screen.getByRole("button", { name: "Se connecter" }));

    const alert = await screen.findByRole("alert");
    expect(alert).toHaveTextContent("Impossible de joindre le serveur. Réessayez.");
    expect(alert.textContent).not.toMatch(/undefined/);
  });

  it("le formulaire de connexion désactive la validation native du navigateur (noValidate)", () => {
    renderLoginPage();

    expect(screen.getByRole("button", { name: "Se connecter" }).closest("form")).toHaveAttribute(
      "novalidate",
    );
  });

  it("un OWNER déjà authentifié est redirigé vers /app/dashboard sans voir le formulaire", async () => {
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

    renderLoginPage();

    await waitFor(() => {
      expect(screen.getByText("Cockpit privé")).toBeInTheDocument();
    });

    expect(screen.queryByRole("heading", { level: 1, name: "Connexion" })).not.toBeInTheDocument();
  });
});
