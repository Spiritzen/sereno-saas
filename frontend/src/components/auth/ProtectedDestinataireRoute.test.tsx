import { render, screen } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";
import * as destinataireApi from "../../api/destinataireApi";
import {
  DESTINATAIRE_SESSION_EXPIREE_EVENT,
  DESTINATAIRE_SESSION_MARKER_KEY,
} from "../../api/destinataireHttp";
import { DestinataireAuthProvider } from "../../context/DestinataireAuthProvider";
import { ProtectedDestinataireRoute } from "./ProtectedDestinataireRoute";

vi.mock("../../api/destinataireApi");

function renderApp() {
  return render(
    <MemoryRouter initialEntries={["/espace-client"]}>
      <DestinataireAuthProvider>
        <Routes>
          <Route
            path="/espace-client"
            element={
              <ProtectedDestinataireRoute>
                <div>Contenu protégé</div>
              </ProtectedDestinataireRoute>
            }
          />
          <Route path="/espace-client/connexion" element={<div>Page connexion</div>} />
        </Routes>
      </DestinataireAuthProvider>
    </MemoryRouter>,
  );
}

describe("ProtectedDestinataireRoute", () => {
  beforeEach(() => {
    window.localStorage.clear();
    vi.clearAllMocks();
  });

  it("non connecté -> redirigé vers /espace-client/connexion", async () => {
    renderApp();

    expect(await screen.findByText("Page connexion")).toBeInTheDocument();
    expect(screen.queryByText("Contenu protégé")).not.toBeInTheDocument();
  });

  it("connecté (marqueur dédié + /moi résolu) -> accède au contenu protégé", async () => {
    window.localStorage.setItem(DESTINATAIRE_SESSION_MARKER_KEY, "true");
    vi.mocked(destinataireApi.moi).mockResolvedValue({ email: "x@test.fr", fournisseurs_lies: 1 });

    renderApp();

    expect(await screen.findByText("Contenu protégé")).toBeInTheDocument();
  });

  it("fix_espace_client_auth_deconnexion — un 401 en cours d'usage redirige, sans laisser le contenu protégé affiché", async () => {
    window.localStorage.setItem(DESTINATAIRE_SESSION_MARKER_KEY, "true");
    vi.mocked(destinataireApi.moi).mockResolvedValue({ email: "x@test.fr", fournisseurs_lies: 1 });

    renderApp();

    expect(await screen.findByText("Contenu protégé")).toBeInTheDocument();

    // Simule l'intercepteur destinataireHttp réagissant à un 401 survenu sur
    // un appel de données (ex. listerFactures), en cours d'usage — pas au
    // montage. Avant le correctif, `compte` restait obsolète en mémoire et
    // le garde continuait de rendre "Contenu protégé".
    window.dispatchEvent(new Event(DESTINATAIRE_SESSION_EXPIREE_EVENT));

    expect(await screen.findByText("Page connexion")).toBeInTheDocument();
    expect(screen.queryByText("Contenu protégé")).not.toBeInTheDocument();
  });
});
