import { render, screen } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";
import * as destinataireApi from "../../api/destinataireApi";
import { DESTINATAIRE_SESSION_MARKER_KEY } from "../../api/destinataireHttp";
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
});
