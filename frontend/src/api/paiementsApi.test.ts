import { describe, expect, it } from "vitest";
import type { Paiement } from "../types/paiement";
import { sommePaiementsConfirmes } from "./paiementsApi";

function paiement(overrides: Partial<Paiement>): Paiement {
  return {
    id: "id",
    facture_id: "facture-id",
    montant: "0",
    methode_code: "58",
    methode_libelle: "Virement SEPA",
    date_encaissement: "2026-08-01",
    reference: null,
    statut: "confirme",
    ...overrides,
  };
}

describe("sommePaiementsConfirmes", () => {
  it("additionne plusieurs paiements confirmés", () => {
    const paiements = [
      paiement({ id: "1", montant: "100.50" }),
      paiement({ id: "2", montant: "49.50" }),
    ];

    expect(sommePaiementsConfirmes(paiements)).toBe(150);
  });

  it("exclut les paiements brouillon et annulé (garde-fou central)", () => {
    const paiements = [
      paiement({ id: "1", montant: "100", statut: "confirme" }),
      paiement({ id: "2", montant: "500", statut: "brouillon" }),
      paiement({ id: "3", montant: "999", statut: "annule" }),
    ];

    expect(sommePaiementsConfirmes(paiements)).toBe(100);
  });

  it("renvoie 0 pour une liste vide", () => {
    expect(sommePaiementsConfirmes([])).toBe(0);
  });
});
