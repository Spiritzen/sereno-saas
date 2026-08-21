import { AxiosHeaders } from "axios";
import { describe, expect, it, vi } from "vitest";
import type { InscriptionInput } from "../types/auth";
import { http } from "./http";
import { inscrire, parseInscriptionError } from "./inscriptionApi";

vi.mock("./http", () => ({
  http: {
    post: vi.fn(),
  },
}));

function payload(): InscriptionInput {
  return {
    utilisateur: {
      prenom: "Sébastien",
      nom: "Cantrelle",
      email: "sebastien@example.test",
      mot_de_passe: "mot-de-passe-solide",
      confirmation_mot_de_passe: "mot-de-passe-solide",
    },
    organisation: {
      raison_sociale: "Studio Démo",
      siret: "12345678901234",
      regime_tva: "reel_normal",
      adresse_ligne1: "1 rue de la Paix",
      code_postal: "80000",
      ville: "Amiens",
      pays: "FR",
      email: "facturation@example.test",
    },
  };
}

describe("inscriptionApi.inscrire", () => {
  it("POST /inscription, payload imbriqué sous `inscription`, credentials via le client canonique (skipRefresh)", async () => {
    vi.mocked(http.post).mockResolvedValue({
      data: {
        message: "Inscription réussie",
        utilisateur: {
          id: "u1",
          email: "sebastien@example.test",
          nom: "Cantrelle",
          prenom: "Sébastien",
          role: "owner",
          actif: true,
        },
        organisation: {
          id: "o1",
          raison_sociale: "Studio Démo",
          siret: "12345678901234",
          regime_tva: "reel_normal",
        },
        session_active: true,
      },
    });

    const input = payload();
    const reponse = await inscrire(input);

    expect(http.post).toHaveBeenCalledWith(
      "/inscription",
      { inscription: input },
      { skipRefresh: true },
    );
    expect(reponse.session_active).toBe(true);
    expect(reponse.utilisateur.role).toBe("owner");
  });
});

function erreurAxios(status: number, data: unknown, headers: Record<string, string> = {}) {
  return {
    isAxiosError: true,
    response: {
      status,
      data,
      headers: new AxiosHeaders(headers),
    },
  };
}

describe("inscriptionApi.parseInscriptionError", () => {
  it("422 -> validation, messages = details bruts (filtrage non-string)", () => {
    const info = parseInscriptionError(
      erreurAxios(422, { error: "Validation échouée", details: ["Le mot de passe est obligatoire.", 42] }),
    );

    expect(info).toEqual({ kind: "validation", messages: ["Le mot de passe est obligatoire."] });
  });

  it("422 sans details -> validation avec messages vides", () => {
    const info = parseInscriptionError(erreurAxios(422, { error: "Validation échouée" }));

    expect(info).toEqual({ kind: "validation", messages: [] });
  });

  it("400 -> malformed", () => {
    const info = parseInscriptionError(erreurAxios(400, { error: "Requête invalide" }));

    expect(info).toEqual({ kind: "malformed" });
  });

  it("429 -> rate_limited, lit Retry-After", () => {
    const info = parseInscriptionError(
      erreurAxios(429, { error: "Trop de tentatives" }, { "retry-after": "42" }),
    );

    expect(info).toEqual({ kind: "rate_limited", retryAfterSeconds: 42 });
  });

  it("429 sans Retry-After -> retryAfterSeconds null", () => {
    const info = parseInscriptionError(erreurAxios(429, { error: "Trop de tentatives" }));

    expect(info).toEqual({ kind: "rate_limited", retryAfterSeconds: null });
  });

  it("5xx -> network", () => {
    const info = parseInscriptionError(erreurAxios(500, { error: "Internal Server Error" }));

    expect(info).toEqual({ kind: "network" });
  });

  it("erreur non-axios (coupure réseau) -> network", () => {
    const info = parseInscriptionError(new Error("Network Error"));

    expect(info).toEqual({ kind: "network" });
  });
});
