import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import type { FactureStatut } from "../types/facture";
import { InvoiceDetailHeader } from "./InvoiceDetailHeader";

function isoDateOffset(days: number): string {
  const date = new Date();
  date.setDate(date.getDate() + days);
  return date.toISOString().slice(0, 10);
}

function renderHeader(overrides: {
  status?: FactureStatut;
  dueDate?: string | null;
}) {
  return render(
    <InvoiceDetailHeader
      invoiceNumber="FA-2026-001"
      status={overrides.status ?? "emise"}
      clientName="Client SAS"
      clientMeta="Paris"
      totalHt={100}
      totalTva={20}
      totalTtc={120}
      currency="EUR"
      invoiceDate="2026-07-01"
      emittedAt="2026-07-02"
      dueDate={overrides.dueDate ?? null}
      hasPdf={false}
      hasXml={false}
      onOpenPdf={vi.fn()}
      onOpenXml={vi.fn()}
    />,
  );
}

describe("InvoiceDetailHeader — échéance (resolveDueInfo)", () => {
  it("affiche 'En retard' pour une échéance passée", () => {
    renderHeader({ status: "emise", dueDate: isoDateOffset(-5) });

    expect(screen.getByText("En retard")).toBeInTheDocument();
  });

  it("affiche 'Échéance proche' pour une échéance dans les 7 jours", () => {
    renderHeader({ status: "emise", dueDate: isoDateOffset(3) });

    expect(screen.getByText("Échéance proche")).toBeInTheDocument();
  });

  it("affiche 'Échéance' (normale) pour une échéance lointaine", () => {
    renderHeader({ status: "emise", dueDate: isoDateOffset(30) });

    expect(screen.getByText("Échéance")).toBeInTheDocument();
  });

  it("n'affiche aucune échéance pour un statut inactif, même en retard (cas négatif)", () => {
    renderHeader({ status: "encaissee", dueDate: isoDateOffset(-5) });

    expect(screen.queryByText("En retard")).not.toBeInTheDocument();
    expect(screen.queryByText(/Échéance/)).not.toBeInTheDocument();
  });
});

describe("InvoiceDetailHeader — mapping statut → libellé", () => {
  it("affiche le libellé 'Brouillon' pour le statut brouillon", () => {
    renderHeader({ status: "brouillon" });

    expect(screen.getByText("Brouillon")).toBeInTheDocument();
  });

  it("affiche le libellé 'Approuvée' pour le statut approuvee", () => {
    renderHeader({ status: "approuvee" });

    expect(screen.getByText("Approuvée")).toBeInTheDocument();
  });
});
