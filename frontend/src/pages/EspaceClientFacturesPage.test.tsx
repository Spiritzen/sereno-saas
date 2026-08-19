import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";
import * as destinataireApi from "../api/destinataireApi";
import { DESTINATAIRE_SESSION_MARKER_KEY } from "../api/destinataireHttp";
import { ProtectedDestinataireRoute } from "../components/auth/ProtectedDestinataireRoute";
import { EspaceClientShell } from "../components/layout/EspaceClientShell";
import { DestinataireAuthProvider } from "../context/DestinataireAuthProvider";
import type { EspaceClientFacturesReponse, EspaceClientGroupeFournisseur } from "../types/espaceClient";
import { EspaceClientFacturesPage } from "./EspaceClientFacturesPage";

vi.mock("../api/destinataireApi");

const GROUPES: EspaceClientGroupeFournisseur[] = [
  {
    fournisseur: { id: "org-1", raison_sociale: "Atelier Nova", logo_url: null },
    factures: [
      {
        id: "fac-1",
        numero: "F-2026-001",
        statut: "emise",
        total_ttc: "120.00",
        devise: "EUR",
        date_emission: "2026-08-01",
        date_echeance: "2026-08-31",
        reste_a_payer: "120.00",
        statut_encaissement_local: "non_payee",
      },
      {
        id: "fac-2",
        numero: "F-2026-002",
        statut: "emise",
        total_ttc: "80.00",
        devise: "EUR",
        date_emission: "2026-07-01",
        date_echeance: "2026-07-31",
        reste_a_payer: "0.00",
        statut_encaissement_local: "soldee",
      },
    ],
  },
];

function reponse(
  groupes: EspaceClientGroupeFournisseur[],
  pagination: Partial<EspaceClientFacturesReponse["pagination"]> = {},
): EspaceClientFacturesReponse {
  return {
    groupes,
    pagination: {
      page: 1,
      par_page: 10,
      total: groupes.flatMap((g) => g.factures).length,
      total_pages: 1,
      ...pagination,
    },
  };
}

function renderPage(initialEntry = "/espace-client") {
  window.localStorage.setItem(DESTINATAIRE_SESSION_MARKER_KEY, "true");
  vi.mocked(destinataireApi.moi).mockResolvedValue({ email: "client@test.fr", fournisseurs_lies: 1 });

  return render(
    <MemoryRouter initialEntries={[initialEntry]}>
      <DestinataireAuthProvider>
        <Routes>
          <Route
            path="/espace-client"
            element={
              <ProtectedDestinataireRoute>
                <EspaceClientShell>
                  <EspaceClientFacturesPage />
                </EspaceClientShell>
              </ProtectedDestinataireRoute>
            }
          />
          <Route path="/espace-client/factures/:id" element={<div>Page détail</div>} />
          <Route path="/espace-client/connexion" element={<div>Page connexion</div>} />
        </Routes>
      </DestinataireAuthProvider>
    </MemoryRouter>,
  );
}

describe("EspaceClientFacturesPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    vi.clearAllMocks();
  });

  it("charge et groupe les factures par fournisseur", async () => {
    vi.mocked(destinataireApi.listerFactures).mockResolvedValue(reponse(GROUPES));

    renderPage();

    expect(await screen.findByText("Atelier Nova")).toBeInTheDocument();
    expect(screen.getByText("F-2026-001")).toBeInTheDocument();
    expect(screen.getByText("F-2026-002")).toBeInTheDocument();
    expect(screen.getByText("2 factures")).toBeInTheDocument();
    expect(destinataireApi.listerFactures).toHaveBeenCalledWith({
      q: undefined,
      statut: undefined,
      tri: "date_desc",
      fournisseur_id: undefined,
      page: 1,
    });
  });

  it("badge de statut : ambre pour en attente/partielle, teal (défaut) pour payée", async () => {
    vi.mocked(destinataireApi.listerFactures).mockResolvedValue(reponse(GROUPES));

    renderPage();

    await screen.findByText("Atelier Nova");

    const ligneEnAttente = screen.getByText("F-2026-001").closest(".invoice-lines-row") as HTMLElement;
    const lignePayee = screen.getByText("F-2026-002").closest(".invoice-lines-row") as HTMLElement;
    expect(within(ligneEnAttente).getByText("En attente")).toHaveClass("badge-paiement--attente");
    expect(within(lignePayee).getByText("Payée")).not.toHaveClass("badge-paiement--attente");
  });

  it("section fournisseur dépliable : ouverte par défaut, repliable au clic", async () => {
    vi.mocked(destinataireApi.listerFactures).mockResolvedValue(reponse(GROUPES));
    const user = userEvent.setup();

    renderPage();

    const summary = await screen.findByText("Atelier Nova");
    const details = summary.closest("details") as HTMLDetailsElement;
    expect(details.open).toBe(true);

    await user.click(summary);
    expect(details.open).toBe(false);
  });

  it("clic sur une facture -> navigue vers son détail", async () => {
    vi.mocked(destinataireApi.listerFactures).mockResolvedValue(reponse(GROUPES));
    const user = userEvent.setup();

    renderPage();

    await user.click(await screen.findByText("F-2026-001"));

    expect(await screen.findByText("Page détail")).toBeInTheDocument();
  });

  it("recherche (soumission du formulaire) -> réinterroge l'API avec le param q, revient à la page 1", async () => {
    vi.mocked(destinataireApi.listerFactures).mockResolvedValue(reponse(GROUPES));
    const user = userEvent.setup();

    renderPage();

    await screen.findByText("Atelier Nova");

    await user.type(screen.getByPlaceholderText("Numéro de facture ou fournisseur"), "Nova");
    await user.click(screen.getByRole("button", { name: "Rechercher" }));

    await waitFor(() => {
      expect(destinataireApi.listerFactures).toHaveBeenLastCalledWith({
        q: "Nova",
        statut: undefined,
        tri: "date_desc",
        fournisseur_id: undefined,
        page: 1,
      });
    });
  });

  it("filtre de statut -> réinterroge l'API immédiatement avec le param statut", async () => {
    vi.mocked(destinataireApi.listerFactures).mockResolvedValue(reponse(GROUPES));
    const user = userEvent.setup();

    renderPage();

    await screen.findByText("Atelier Nova");

    await user.selectOptions(screen.getByLabelText("Statut"), "payee");

    await waitFor(() => {
      expect(destinataireApi.listerFactures).toHaveBeenLastCalledWith({
        q: undefined,
        statut: "payee",
        tri: "date_desc",
        fournisseur_id: undefined,
        page: 1,
      });
    });
  });

  it("tri -> réinterroge l'API immédiatement avec le param tri", async () => {
    vi.mocked(destinataireApi.listerFactures).mockResolvedValue(reponse(GROUPES));
    const user = userEvent.setup();

    renderPage();

    await screen.findByText("Atelier Nova");

    await user.selectOptions(screen.getByLabelText("Trier par"), "montant_desc");

    await waitFor(() => {
      expect(destinataireApi.listerFactures).toHaveBeenLastCalledWith({
        q: undefined,
        statut: undefined,
        tri: "montant_desc",
        fournisseur_id: undefined,
        page: 1,
      });
    });
  });

  it("?fournisseur=<id> dans l'URL -> transmis en fournisseur_id, bandeau de filtre affiché", async () => {
    vi.mocked(destinataireApi.listerFactures).mockResolvedValue(reponse(GROUPES));

    renderPage("/espace-client?fournisseur=org-1");

    await screen.findByText("Atelier Nova");

    expect(destinataireApi.listerFactures).toHaveBeenCalledWith({
      q: undefined,
      statut: undefined,
      tri: "date_desc",
      fournisseur_id: "org-1",
      page: 1,
    });
    expect(screen.getByText("Filtré sur un fournisseur")).toBeInTheDocument();
  });

  it("pagination : Suivant/Précédent réinterrogent l'API avec le bon `page`", async () => {
    vi.mocked(destinataireApi.listerFactures)
      .mockResolvedValueOnce(reponse(GROUPES, { page: 1, total: 15, total_pages: 2 }))
      .mockResolvedValueOnce(reponse(GROUPES, { page: 2, total: 15, total_pages: 2 }))
      .mockResolvedValueOnce(reponse(GROUPES, { page: 1, total: 15, total_pages: 2 }));
    const user = userEvent.setup();

    renderPage();

    await screen.findByText("Page 1/2 · 15 factures");

    await user.click(screen.getByRole("button", { name: /Suivant/ }));

    await waitFor(() => {
      expect(destinataireApi.listerFactures).toHaveBeenLastCalledWith({
        q: undefined,
        statut: undefined,
        tri: "date_desc",
        fournisseur_id: undefined,
        page: 2,
      });
    });
    await screen.findByText("Page 2/2 · 15 factures");

    await user.click(screen.getByRole("button", { name: /Précédent/ }));

    await waitFor(() => {
      expect(destinataireApi.listerFactures).toHaveBeenLastCalledWith({
        q: undefined,
        statut: undefined,
        tri: "date_desc",
        fournisseur_id: undefined,
        page: 1,
      });
    });
  });

  it("une seule page -> aucun contrôle de pagination affiché", async () => {
    vi.mocked(destinataireApi.listerFactures).mockResolvedValue(reponse(GROUPES));

    renderPage();

    await screen.findByText("Atelier Nova");

    expect(screen.queryByRole("button", { name: /Suivant/ })).not.toBeInTheDocument();
  });

  it("liste vide -> état vide sobre", async () => {
    vi.mocked(destinataireApi.listerFactures).mockResolvedValue(reponse([], { total: 0 }));

    renderPage();

    expect(await screen.findByText("Aucune facture pour le moment.")).toBeInTheDocument();
  });

  it("erreur -> état d'erreur avec bouton Réessayer qui relance l'appel", async () => {
    vi.mocked(destinataireApi.listerFactures)
      .mockRejectedValueOnce({
        response: { data: { error: "Erreur serveur" } },
        isAxiosError: true,
      })
      .mockResolvedValueOnce(reponse(GROUPES));
    const user = userEvent.setup();

    renderPage();

    expect(await screen.findByText("Erreur serveur")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Réessayer" }));

    expect(await screen.findByText("Atelier Nova")).toBeInTheDocument();
    expect(destinataireApi.listerFactures).toHaveBeenCalledTimes(2);
  });

  it("fix_espace_client_auth_deconnexion — 401 : jamais de bandeau d'erreur, la redirection prend le relais", async () => {
    vi.mocked(destinataireApi.listerFactures).mockRejectedValue({
      response: { status: 401, data: { error: "Authentification requise" } },
      isAxiosError: true,
    });

    renderPage();

    await waitFor(() => {
      expect(screen.queryByText("Chargement de vos factures...")).not.toBeInTheDocument();
    });

    expect(screen.queryByText("Authentification requise")).not.toBeInTheDocument();
    expect(screen.queryByText(/^Erreur/)).not.toBeInTheDocument();
  });
});
