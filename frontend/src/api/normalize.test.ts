import { describe, expect, it } from "vitest";
import { normalizeCollection, normalizeResource } from "./normalize";

describe("normalizeCollection", () => {
  it("déplie un tableau direct", () => {
    const payload = [{ id: "1" }, { id: "2" }];

    expect(normalizeCollection(payload, "paiements")).toEqual(payload);
  });

  it("déplie une réponse enveloppée sous la clé de ressource (forme réelle du backend)", () => {
    const payload = { paiements: [{ id: "1" }] };

    expect(normalizeCollection(payload, "paiements")).toEqual([{ id: "1" }]);
  });

  it("accepte une collection vide sans erreur", () => {
    const payload = { paiements: [] };

    expect(normalizeCollection(payload, "paiements")).toEqual([]);
  });

  it("lève une erreur explicite sur une forme inattendue au lieu de crasher silencieusement", () => {
    const payload = { autreCle: [{ id: "1" }] };

    expect(() => normalizeCollection(payload, "paiements")).toThrow(
      /paiements/,
    );
  });
});

describe("normalizeResource", () => {
  it("déplie une ressource enveloppée sous sa clé", () => {
    const payload = { paiement: { id: "1", montant: "10.00" } };

    expect(normalizeResource(payload, "paiement")).toEqual({
      id: "1",
      montant: "10.00",
    });
  });

  it("déplie une ressource enveloppée sous 'data'", () => {
    const payload = { data: { id: "1" } };

    expect(normalizeResource(payload, "paiement")).toEqual({ id: "1" });
  });

  it("renvoie le payload tel quel si la clé attendue est absente (pas de throw)", () => {
    const payload = { id: "1", montant: "10.00" };

    expect(normalizeResource(payload, "paiement")).toEqual(payload);
  });
});
