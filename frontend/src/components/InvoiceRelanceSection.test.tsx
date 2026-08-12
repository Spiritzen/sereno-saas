import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import * as relancesApi from "../api/relancesApi";
import type { Facture } from "../types/facture";
import type { Relance, RelanceResult } from "../types/relance";
import { InvoiceRelanceSection } from "./InvoiceRelanceSection";

vi.mock("../api/relancesApi");

function facture(overrides: Partial<Facture> = {}): Facture {
  return {
    id: "facture-1",
    client_id: "client-1",
    numero: "FAC-2026-0001",
    type_document: "facture",
    statut: "emise",
    date_emission: "2026-07-01",
    date_echeance: "2026-07-31",
    total_ht: "200",
    total_tva: "40",
    total_ttc: "240",
    devise: "EUR",
    format: "factur_x",
    mentions: null,
    conditions_paiement: null,
    pdf_url: null,
    xml_url: null,
    emise_at: "2026-07-01T10:00:00Z",
    relancable: true,
    derniere_relance_at: null,
    relances_count: 0,
    ...overrides,
  };
}

function relance(overrides: Partial<Relance> = {}): Relance {
  return {
    id: "relance-1",
    facture_id: "facture-1",
    canal: "email",
    statut: "envoyee",
    destinataire_email: "client@test.fr",
    objet: "Rappel de paiement — facture FAC-2026-0001",
    mode_livraison: "letter_opener",
    envoyee_at: "2026-08-05T09:00:00Z",
    ...overrides,
  };
}

describe("InvoiceRelanceSection — bouton manuel (relances v1a)", () => {
  it("n'affiche aucun bouton ni section si la facture n'est ni relançable ni déjà relancée", () => {
    render(
      <InvoiceRelanceSection
        factureId="facture-1"
        relancable={false}
        derniereRelanceAt={null}
        relancesCount={0}
        onFactureMutated={vi.fn()}
      />,
    );

    expect(
      screen.queryByRole("button", { name: "Relancer" }),
    ).not.toBeInTheDocument();
  });

  it("affiche le bouton Relancer quand la facture est éligible", () => {
    render(
      <InvoiceRelanceSection
        factureId="facture-1"
        relancable={true}
        derniereRelanceAt={null}
        relancesCount={0}
        onFactureMutated={vi.fn()}
      />,
    );

    expect(
      screen.getByRole("button", { name: "Relancer" }),
    ).toBeInTheDocument();
    expect(
      screen.getByText("Aucune relance envoyée pour le moment."),
    ).toBeInTheDocument();
  });

  it("au clic, envoie la relance puis affiche la date de dernière relance", async () => {
    const user = userEvent.setup();
    const onFactureMutated = vi.fn();
    const factureAJour = facture({
      derniere_relance_at: "2026-08-05T09:00:00Z",
      relances_count: 1,
    });

    const result: RelanceResult = {
      relance: relance(),
      facture: factureAJour,
    };
    vi.mocked(relancesApi.relancerFacture).mockResolvedValue(result);

    render(
      <InvoiceRelanceSection
        factureId="facture-1"
        relancable={true}
        derniereRelanceAt={null}
        relancesCount={0}
        onFactureMutated={onFactureMutated}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Relancer" }));

    await waitFor(() =>
      expect(relancesApi.relancerFacture).toHaveBeenCalledWith("facture-1"),
    );
    expect(onFactureMutated).toHaveBeenCalledWith(factureAJour);
    expect(
      await screen.findByText(/prévisu dev \(letter_opener\)/),
    ).toBeInTheDocument();
  });

  it("affiche l'erreur API sans faire disparaître le bouton", async () => {
    const user = userEvent.setup();
    vi.mocked(relancesApi.relancerFacture).mockRejectedValue({
      response: { data: { error: "Facture non éligible" } },
      isAxiosError: true,
    });

    render(
      <InvoiceRelanceSection
        factureId="facture-1"
        relancable={true}
        derniereRelanceAt={null}
        relancesCount={0}
        onFactureMutated={vi.fn()}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Relancer" }));

    expect(await screen.findByText("Facture non éligible")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Relancer" })).toBeInTheDocument();
  });
});
