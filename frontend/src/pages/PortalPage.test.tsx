import { render, screen } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { describe, expect, it, vi } from "vitest";
import * as portailApi from "../api/portailApi";
import type { PortailFacture } from "../types/portail";
import { PortalPage } from "./PortalPage";

// Portail destinataire (MVP) — la page ne parle qu'à portailApi (client
// public dédié, jamais `http`/facturesApi authentifiés). Zéro appel réseau
// réel : portailApi est automocké.
vi.mock("../api/portailApi");

function buildFacture(overrides: Partial<PortailFacture> = {}): PortailFacture {
  return {
    id: "facture-1",
    numero: "FAC-2026-0001",
    type_document: "facture",
    statut: "emise",
    total_ht: "200.00",
    total_tva: "40.00",
    total_ttc: "240.00",
    devise: "EUR",
    mentions: null,
    conditions_paiement: null,
    date_emission: "2026-07-01",
    date_echeance: "2026-07-31",
    emise_at: "2026-07-01T10:00:00Z",
    pdf_disponible: true,
    reste_a_payer: "240.00",
    statut_encaissement_local: "non_payee",
    client: {
      id: "client-1",
      type: "entreprise",
      raison_sociale: "Client Test SAS",
      siret: "12345678900012",
      numero_tva: null,
      adresse_ligne1: "1 rue de Test",
      adresse_ligne2: null,
      code_postal: "75001",
      ville: "Paris",
      pays: "FR",
    },
    lignes_facture: [],
    ...overrides,
  };
}

function renderPortalPage(token: string) {
  return render(
    <MemoryRouter initialEntries={[`/portail/${token}`]}>
      <Routes>
        <Route path="/portail/:token" element={<PortalPage />} />
      </Routes>
    </MemoryRouter>,
  );
}

describe("PortalPage — portail destinataire (MVP)", () => {
  it("affiche la facture pour un token valide" , async () => {
    vi.mocked(portailApi.getFacturePortail).mockResolvedValue(buildFacture());
    vi.mocked(portailApi.listAvoirsPortail).mockResolvedValue([]);

    renderPortalPage("un-token-brut");

    expect(await screen.findByText("FAC-2026-0001")).toBeInTheDocument();
    expect(screen.getByText("Client Test SAS")).toBeInTheDocument();
    expect(portailApi.getFacturePortail).toHaveBeenCalledWith("un-token-brut");
  });

  it("affiche le bouton téléchargement PDF quand pdf_disponible est vrai" , async () => {
    vi.mocked(portailApi.getFacturePortail).mockResolvedValue(
      buildFacture({ pdf_disponible: true }),
    );
    vi.mocked(portailApi.listAvoirsPortail).mockResolvedValue([]);

    renderPortalPage("un-token-brut");

    expect(
      await screen.findByRole("button", { name: /Télécharger le PDF/ }),
    ).toBeInTheDocument();
  });

  it("masque le bouton téléchargement PDF quand pdf_disponible est faux" , async () => {
    vi.mocked(portailApi.getFacturePortail).mockResolvedValue(
      buildFacture({ pdf_disponible: false }),
    );
    vi.mocked(portailApi.listAvoirsPortail).mockResolvedValue([]);

    renderPortalPage("un-token-brut");

    await screen.findByText("FAC-2026-0001");
    expect(
      screen.queryByRole("button", { name: /Télécharger le PDF/ }),
    ).not.toBeInTheDocument();
  });

  it("n'affiche jamais de lien vers le reste de l'application (page autonome)" , async () => {
    vi.mocked(portailApi.getFacturePortail).mockResolvedValue(buildFacture());
    vi.mocked(portailApi.listAvoirsPortail).mockResolvedValue([]);

    renderPortalPage("un-token-brut");

    await screen.findByText("FAC-2026-0001");
    expect(screen.queryAllByRole("link")).toHaveLength(0);
  });

  it("affiche un message générique et sobre pour un token invalide/expiré — aucune fuite du cas réel" , async () => {
    vi.mocked(portailApi.getFacturePortail).mockRejectedValue({
      response: { data: { error: "Lien invalide ou expiré" } },
      isAxiosError: true,
    });
    vi.mocked(portailApi.listAvoirsPortail).mockResolvedValue([]);

    renderPortalPage("token-invalide");

    expect(
      await screen.findByText(/Ce lien n'est plus valide/),
    ).toBeInTheDocument();
    expect(screen.queryByText("FAC-2026-0001")).not.toBeInTheDocument();
  });

  it("affiche les avoirs liés renvoyés par l'API" , async () => {
    vi.mocked(portailApi.getFacturePortail).mockResolvedValue(buildFacture());
    vi.mocked(portailApi.listAvoirsPortail).mockResolvedValue([
      {
        id: "avoir-1",
        numero: "AV-2026-0001",
        motif: "Erreur de facturation",
        statut: "emise",
        total_ht: "50.00",
        total_tva: "10.00",
        total_ttc: "60.00",
        date_emission: "2026-08-01",
        emis_at: "2026-08-01T10:00:00Z",
      },
    ]);

    renderPortalPage("un-token-brut");

    expect(await screen.findByText("AV-2026-0001")).toBeInTheDocument();
  });
});
