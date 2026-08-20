import { render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { afterEach, describe, expect, it, vi } from "vitest";
import * as authApi from "../../api/authApi";
import { AuthProvider } from "../../context/AuthProvider";
import { ProtectedRoute } from "./ProtectedRoute";

// R1 (prompt_claude_code_entree_publique_r1_landing.txt §8.9/§8) — fige le
// comportement RÉEL du garde privé AVANT toute modification du routage
// public : ce fichier n'existait pas avant ce sprint (cf. rapport de
// reconnaissance R0). Zéro mock réseau réel : authApi automocké, comme
// AppShell.test.tsx.
vi.mock("../../api/authApi");

function renderProtected() {
  return render(
    <MemoryRouter initialEntries={["/app/dashboard"]}>
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<div>Page de connexion</div>} />
          <Route
            path="/app/dashboard"
            element={
              <ProtectedRoute>
                <div>Contenu privé du dashboard</div>
              </ProtectedRoute>
            }
          />
        </Routes>
      </AuthProvider>
    </MemoryRouter>,
  );
}

afterEach(() => {
  window.localStorage.clear();
});

describe("ProtectedRoute — non-régression du garde privé", () => {
  it("un visiteur anonyme (aucun marqueur de session) est redirigé vers /login sans jamais voir le contenu privé", () => {
    renderProtected();

    expect(screen.getByText("Page de connexion")).toBeInTheDocument();
    expect(screen.queryByText("Contenu privé du dashboard")).not.toBeInTheDocument();
  });

  it("affiche un état de chargement pendant la résolution de la session, jamais le contenu privé prématurément", async () => {
    window.localStorage.setItem("sereno.session.active", "true");
    vi.mocked(authApi.me).mockReturnValue(new Promise(() => {}));

    renderProtected();

    expect(screen.getByText(/Chargement de votre espace Sereno/i)).toBeInTheDocument();
    expect(screen.queryByText("Contenu privé du dashboard")).not.toBeInTheDocument();
    expect(screen.queryByText("Page de connexion")).not.toBeInTheDocument();
  });

  it("un utilisateur réellement authentifié voit le contenu privé, jamais la page de connexion", async () => {
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

    renderProtected();

    await waitFor(() => {
      expect(screen.getByText("Contenu privé du dashboard")).toBeInTheDocument();
    });

    expect(screen.queryByText("Page de connexion")).not.toBeInTheDocument();
  });

  it("un marqueur de session dont la vérification échoue redirige finalement vers /login", async () => {
    window.localStorage.setItem("sereno.session.active", "true");
    vi.mocked(authApi.me).mockRejectedValue(new Error("Session invalide"));

    renderProtected();

    await waitFor(() => {
      expect(screen.getByText("Page de connexion")).toBeInTheDocument();
    });

    expect(screen.queryByText("Contenu privé du dashboard")).not.toBeInTheDocument();
  });
});
