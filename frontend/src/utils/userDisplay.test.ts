import { describe, expect, it } from "vitest";
import type { Utilisateur } from "../types/auth";
import { getUserFullName, getUserInitials, getUserRoleLabel } from "./userDisplay";

function buildUtilisateur(overrides: Partial<Utilisateur> = {}): Utilisateur {
  return {
    id: "user-1",
    email: "sebastien@test.fr",
    nom: "Cantrelle",
    prenom: "Sébastien",
    role: "owner",
    actif: true,
    ...overrides,
  };
}

describe("userDisplay", () => {
  it("construit les initiales à partir du prénom et du nom", () => {
    expect(getUserInitials(buildUtilisateur())).toBe("SC");
  });

  it("cas négatif — sans utilisateur, retombe sur des initiales neutres", () => {
    expect(getUserInitials(null)).toBe("SC");
  });

  it("retombe sur l'email quand prénom/nom sont vides", () => {
    expect(
      getUserInitials(buildUtilisateur({ prenom: "", nom: "", email: "ab@test.fr" })),
    ).toBe("AB");
  });

  it("construit le nom complet", () => {
    expect(getUserFullName(buildUtilisateur())).toBe("Sébastien Cantrelle");
  });

  it("cas négatif — sans utilisateur, nom complet générique", () => {
    expect(getUserFullName(null)).toBe("Utilisateur");
  });

  it("traduit chaque rôle en libellé lisible", () => {
    expect(getUserRoleLabel(buildUtilisateur({ role: "comptable" }))).toBe("Comptable");
  });
});
