import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import * as destinataireApi from "../api/destinataireApi";
import {
  DESTINATAIRE_SESSION_EXPIREE_EVENT,
  DESTINATAIRE_SESSION_MARKER_KEY,
} from "../api/destinataireHttp";
import { DestinataireAuthProvider } from "./DestinataireAuthProvider";
import { useDestinataireAuth } from "./useDestinataireAuth";

vi.mock("../api/destinataireApi");

// Sonde qui expose le contexte pour l'assertion, sans passer par une page
// (jumeau direct de ce que AuthProvider n'a jamais eu comme test dédié,
// posé pour la 1ʳᵉ fois côté espace client).
function Sonde() {
  const { compte, isAuthenticated, isLoading, login, logout } = useDestinataireAuth();

  return (
    <div>
      <span data-testid="loading">{String(isLoading)}</span>
      <span data-testid="authenticated">{String(isAuthenticated)}</span>
      <span data-testid="email">{compte?.email ?? ""}</span>
      <button onClick={() => void login({ email: "x@test.fr", mot_de_passe: "motdepasse123" })}>
        Connexion
      </button>
      <button onClick={() => void logout()}>Déconnexion</button>
    </div>
  );
}

describe("DestinataireAuthProvider", () => {
  beforeEach(() => {
    window.localStorage.clear();
    vi.clearAllMocks();
  });

  it("login stocke la session sous la clé DÉDIÉE — jamais celle de l'app", async () => {
    const user = userEvent.setup();
    vi.mocked(destinataireApi.connexion).mockResolvedValue({ email: "x@test.fr", fournisseurs_lies: 1 });

    render(
      <DestinataireAuthProvider>
        <Sonde />
      </DestinataireAuthProvider>,
    );

    await user.click(screen.getByText("Connexion"));

    await waitFor(() => expect(screen.getByTestId("authenticated").textContent).toBe("true"));
    expect(window.localStorage.getItem(DESTINATAIRE_SESSION_MARKER_KEY)).toBe("true");
    expect(window.localStorage.getItem("sereno.session.active")).toBeNull();
  });

  it("logout nettoie le marqueur dédié et l'état du compte", async () => {
    const user = userEvent.setup();
    vi.mocked(destinataireApi.connexion).mockResolvedValue({ email: "x@test.fr", fournisseurs_lies: 1 });
    vi.mocked(destinataireApi.deconnexion).mockResolvedValue();

    render(
      <DestinataireAuthProvider>
        <Sonde />
      </DestinataireAuthProvider>,
    );

    await user.click(screen.getByText("Connexion"));
    await waitFor(() => expect(screen.getByTestId("authenticated").textContent).toBe("true"));

    await user.click(screen.getByText("Déconnexion"));

    await waitFor(() => expect(screen.getByTestId("authenticated").textContent).toBe("false"));
    expect(window.localStorage.getItem(DESTINATAIRE_SESSION_MARKER_KEY)).toBeNull();
  });

  it("fix_espace_client_auth_deconnexion — logout nettoie MÊME si le backend échoue (session déjà morte)", async () => {
    const user = userEvent.setup();
    vi.mocked(destinataireApi.connexion).mockResolvedValue({ email: "x@test.fr", fournisseurs_lies: 1 });
    vi.mocked(destinataireApi.deconnexion).mockRejectedValue({
      response: { status: 401, data: { error: "Authentification requise" } },
      isAxiosError: true,
    });

    render(
      <DestinataireAuthProvider>
        <Sonde />
      </DestinataireAuthProvider>,
    );

    await user.click(screen.getByText("Connexion"));
    await waitFor(() => expect(screen.getByTestId("authenticated").textContent).toBe("true"));

    await user.click(screen.getByText("Déconnexion"));

    // Même si le DELETE backend a échoué (401), l'état local est nettoyé
    // sans résidu — condition nécessaire pour pouvoir se reconnecter ensuite.
    await waitFor(() => expect(screen.getByTestId("authenticated").textContent).toBe("false"));
    expect(window.localStorage.getItem(DESTINATAIRE_SESSION_MARKER_KEY)).toBeNull();
  });

  it("fix_espace_client_auth_deconnexion — un 401 destinataire (n'importe où) invalide compte SANS rechargement", async () => {
    const user = userEvent.setup();
    vi.mocked(destinataireApi.connexion).mockResolvedValue({ email: "x@test.fr", fournisseurs_lies: 1 });

    render(
      <DestinataireAuthProvider>
        <Sonde />
      </DestinataireAuthProvider>,
    );

    await user.click(screen.getByText("Connexion"));
    await waitFor(() => expect(screen.getByTestId("authenticated").textContent).toBe("true"));

    // Simule l'intercepteur destinataireHttp réagissant à un 401 sur un
    // appel quelconque (ex. listerFactures) — sans passer par logout().
    window.dispatchEvent(new Event(DESTINATAIRE_SESSION_EXPIREE_EVENT));

    await waitFor(() => expect(screen.getByTestId("authenticated").textContent).toBe("false"));
  });

  it("« qui suis-je » au montage SI le marqueur dédié est déjà présent", async () => {
    window.localStorage.setItem(DESTINATAIRE_SESSION_MARKER_KEY, "true");
    vi.mocked(destinataireApi.moi).mockResolvedValue({ email: "deja@test.fr", fournisseurs_lies: 2 });

    render(
      <DestinataireAuthProvider>
        <Sonde />
      </DestinataireAuthProvider>,
    );

    await waitFor(() => expect(screen.getByTestId("authenticated").textContent).toBe("true"));
    expect(screen.getByTestId("email").textContent).toBe("deja@test.fr");
  });

  it("ne tente PAS « qui suis-je » si le marqueur dédié est absent", () => {
    render(
      <DestinataireAuthProvider>
        <Sonde />
      </DestinataireAuthProvider>,
    );

    expect(destinataireApi.moi).not.toHaveBeenCalled();
    expect(screen.getByTestId("loading").textContent).toBe("false");
  });
});
