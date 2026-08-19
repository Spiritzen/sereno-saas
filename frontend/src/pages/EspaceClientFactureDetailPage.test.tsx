import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";
import * as destinataireApi from "../api/destinataireApi";
import { DESTINATAIRE_SESSION_MARKER_KEY } from "../api/destinataireHttp";
import { EspaceClientShell } from "../components/layout/EspaceClientShell";
import { DestinataireAuthProvider } from "../context/DestinataireAuthProvider";
import type { EspaceClientFactureDetail } from "../types/espaceClient";
import { EspaceClientFactureDetailPage } from "./EspaceClientFactureDetailPage";

vi.mock("../api/destinataireApi");

const DETAIL: EspaceClientFactureDetail = {
  fournisseur: { id: "org-1", raison_sociale: "Atelier Nova", logo_url: null },
  facture: {
    id: "fac-1",
    numero: "F-2026-001",
    type_document: "facture",
    statut: "emise",
    total_ht: "100.00",
    total_tva: "20.00",
    total_ttc: "120.00",
    devise: "EUR",
    mentions: null,
    conditions_paiement: null,
    date_emission: "2026-08-01",
    date_echeance: "2026-08-31",
    emise_at: "2026-08-01T10:00:00Z",
    reste_a_payer: "120.00",
    statut_encaissement_local: "non_payee",
    pdf_disponible: true,
    client: {
      id: "cli-1",
      type: "entreprise",
      raison_sociale: "Client Test",
      siret: null,
      numero_tva: null,
      adresse_ligne1: "1 rue Test",
      adresse_ligne2: null,
      code_postal: "75000",
      ville: "Paris",
      pays: "France",
    },
    lignes_facture: [
      {
        id: "ligne-1",
        facture_id: "fac-1",
        produit_id: null,
        designation: "Prestation conseil",
        quantite: "1.00",
        prix_unitaire_ht: "100.00",
        taux_tva: "20.00",
        montant_tva: "20.00",
        total_ht: "100.00",
        total_ttc: "120.00",
        position: 1,
      },
    ],
  },
  avoirs: [],
};

function renderPage(id = "fac-1") {
  window.localStorage.setItem(DESTINATAIRE_SESSION_MARKER_KEY, "true");
  vi.mocked(destinataireApi.moi).mockResolvedValue({ email: "client@test.fr", fournisseurs_lies: 1 });

  return render(
    <MemoryRouter initialEntries={[`/espace-client/factures/${id}`]}>
      <DestinataireAuthProvider>
        <Routes>
          <Route
            path="/espace-client/factures/:id"
            element={
              <EspaceClientShell>
                <EspaceClientFactureDetailPage />
              </EspaceClientShell>
            }
          />
          <Route path="/espace-client" element={<div>Page liste</div>} />
        </Routes>
      </DestinataireAuthProvider>
    </MemoryRouter>,
  );
}

describe("EspaceClientFactureDetailPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    vi.clearAllMocks();
  });

  it("affiche l'en-tête, les lignes et les totaux de la facture", async () => {
    vi.mocked(destinataireApi.getFacture).mockResolvedValue(DETAIL);

    renderPage();

    expect(await screen.findByText("F-2026-001")).toBeInTheDocument();
    expect(screen.getByText("Atelier Nova")).toBeInTheDocument();
    expect(screen.getByText("Prestation conseil")).toBeInTheDocument();
    expect(destinataireApi.getFacture).toHaveBeenCalledWith("fac-1");
  });

  it("§1 execution_espace_client_sidebar_pagination_badge.txt — badge ambre pour non_payee, teal pour soldee", async () => {
    vi.mocked(destinataireApi.getFacture).mockResolvedValueOnce(DETAIL); // non_payee

    const { unmount } = renderPage();

    expect(await screen.findByText("En attente")).toHaveClass("badge-paiement--attente");
    unmount();

    vi.mocked(destinataireApi.getFacture).mockResolvedValueOnce({
      ...DETAIL,
      facture: { ...DETAIL.facture, statut_encaissement_local: "soldee", reste_a_payer: "0.00" },
    });

    renderPage();

    expect(await screen.findByText("Payée")).not.toHaveClass("badge-paiement--attente");
  });

  it("affiche les avoirs quand présents", async () => {
    vi.mocked(destinataireApi.getFacture).mockResolvedValue({
      ...DETAIL,
      avoirs: [
        {
          id: "avoir-1",
          numero: "A-2026-001",
          motif: "Remise commerciale",
          statut: "emis",
          total_ht: "10.00",
          total_tva: "2.00",
          total_ttc: "12.00",
          date_emission: "2026-08-05",
          emis_at: "2026-08-05T10:00:00Z",
        },
      ],
    });

    renderPage();

    expect(await screen.findByText("A-2026-001")).toBeInTheDocument();
    expect(screen.getByText("Remise commerciale")).toBeInTheDocument();
  });

  it("bouton Télécharger le PDF -> ouvre la bonne URL", async () => {
    vi.mocked(destinataireApi.getFacture).mockResolvedValue(DETAIL);
    vi.mocked(destinataireApi.getFacturePdfUrl).mockReturnValue(
      "http://localhost:3000/destinataire/factures/fac-1/pdf",
    );
    const openSpy = vi.spyOn(window, "open").mockImplementation(() => null);
    const user = userEvent.setup();

    renderPage();

    await screen.findByText("F-2026-001");

    await user.click(screen.getByRole("button", { name: /Télécharger le PDF/i }));

    expect(openSpy).toHaveBeenCalledWith(
      "http://localhost:3000/destinataire/factures/fac-1/pdf",
      "_blank",
      "noopener,noreferrer",
    );
  });

  it("404 -> état sobre 'Facture introuvable' avec retour à la liste", async () => {
    vi.mocked(destinataireApi.getFacture).mockRejectedValue({
      response: { status: 404, data: { error: "Ressource introuvable" } },
      isAxiosError: true,
    });
    const user = userEvent.setup();

    renderPage();

    expect(await screen.findByText("Facture introuvable.")).toBeInTheDocument();

    await user.click(screen.getAllByRole("link", { name: "Retour à mes factures" })[0]);

    expect(await screen.findByText("Page liste")).toBeInTheDocument();
  });

  it("erreur non-404 -> message d'erreur générique", async () => {
    vi.mocked(destinataireApi.getFacture).mockRejectedValue({
      response: { status: 500, data: { error: "Erreur serveur" } },
      isAxiosError: true,
    });

    renderPage();

    expect(await screen.findByText("Erreur serveur")).toBeInTheDocument();
  });
});
