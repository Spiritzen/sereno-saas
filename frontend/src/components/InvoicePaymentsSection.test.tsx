import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import * as paiementsApi from "../api/paiementsApi";
import type { Paiement } from "../types/paiement";
import { InvoicePaymentsSection } from "./InvoicePaymentsSection";

// "Cible 5" (dette de testabilité fermée par l'extraction, cf. étage C) :
// validation du formulaire de paiement (montant > 0, moyen UNTDID 4461).
// Zéro appel réseau réel : paiementsApi est automocké par Vitest (aucune
// factory fournie -> chaque export devient un vi.fn()).
vi.mock("../api/paiementsApi");

function paiement(overrides: Partial<Paiement>): Paiement {
  return {
    id: "p1",
    facture_id: "facture-1",
    montant: "150",
    methode_code: "58",
    methode_libelle: "Virement SEPA",
    date_encaissement: "2026-08-03",
    reference: null,
    statut: "brouillon",
    ...overrides,
  };
}

describe("InvoicePaymentsSection — formulaire d'enregistrement (cible 5)", () => {
  beforeEach(() => {
    vi.mocked(paiementsApi.listPaiements).mockResolvedValue([]);
  });

  it("refuse la soumission sans montant renseigné (cas négatif) et n'appelle jamais l'API", async () => {
    const user = userEvent.setup();

    render(
      <InvoicePaymentsSection
        factureId="facture-1"
        montantPaye={0}
        resteDu={150}
        resteAPayer={150}
        onFactureMutated={vi.fn()}
      />,
    );

    await screen.findByText(
      "Aucun paiement n’a encore été enregistré pour cette facture.",
    );

    await user.click(
      screen.getByRole("button", { name: "Enregistrer un paiement" }),
    );

    expect(
      await screen.findByText("Le montant doit être supérieur à 0."),
    ).toBeInTheDocument();
    expect(paiementsApi.createPaiement).not.toHaveBeenCalled();
  });

  it("accepte un montant valide avec un moyen UNTDID 4461 sélectionné par défaut, enregistre puis confirme le paiement", async () => {
    const user = userEvent.setup();
    const onFactureMutated = vi.fn();

    vi.mocked(paiementsApi.createPaiement).mockResolvedValue(
      paiement({ statut: "brouillon" }),
    );
    vi.mocked(paiementsApi.confirmerPaiement).mockResolvedValue(
      paiement({ statut: "confirme" }),
    );

    render(
      <InvoicePaymentsSection
        factureId="facture-1"
        montantPaye={0}
        resteDu={150}
        resteAPayer={150}
        onFactureMutated={onFactureMutated}
      />,
    );

    await screen.findByText(
      "Aucun paiement n’a encore été enregistré pour cette facture.",
    );

    const moyenSelect = screen.getByLabelText("Moyen");
    expect(moyenSelect).toHaveValue("58"); // moyen 4461 valide déjà sélectionné

    await user.type(screen.getByLabelText("Montant"), "150");
    await user.click(
      screen.getByRole("button", { name: "Enregistrer un paiement" }),
    );

    await waitFor(() =>
      expect(paiementsApi.createPaiement).toHaveBeenCalledWith(
        "facture-1",
        expect.objectContaining({ montant: 150, methode_code: "58" }),
      ),
    );
    expect(paiementsApi.confirmerPaiement).toHaveBeenCalledWith(
      "facture-1",
      "p1",
    );
    await waitFor(() => expect(onFactureMutated).toHaveBeenCalled());
  });
});
