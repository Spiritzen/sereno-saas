import axios from "axios";
import type { InscriptionInput, InscriptionResponse } from "../types/auth";
import { http } from "./http";

export async function inscrire(input: InscriptionInput): Promise<InscriptionResponse> {
  const response = await http.post<InscriptionResponse>(
    "/inscription",
    { inscription: input },
    {
      // Même discipline que authApi.login/me/logout : cet appel ne doit
      // jamais déclencher une tentative de refresh (aucune session
      // n'existe encore avant l'inscription).
      skipRefresh: true,
    },
  );

  return response.data;
}

// R3 (§8/§14) — union discriminée permettant à l'UI de distinguer 400/422/
// 429/réseau SANS jamais réafficher un détail SQL, une exception ou un nom
// de paramètre interne. `messages` (422) ne contient QUE des chaînes déjà
// sobres et françaises (cf. parseInscriptionError) — jamais le texte brut
// non maîtrisé d'une validation Rails en anglais (cf. rapport §16).
export type InscriptionErrorInfo =
  | { kind: "validation"; messages: string[] }
  | { kind: "malformed" }
  | { kind: "rate_limited"; retryAfterSeconds: number | null }
  | { kind: "network" };

export function parseInscriptionError(error: unknown): InscriptionErrorInfo {
  if (axios.isAxiosError(error)) {
    const status = error.response?.status;

    if (status === 422) {
      const data = error.response?.data as { details?: unknown } | undefined;
      const rawDetails = Array.isArray(data?.details) ? data.details : [];

      return { kind: "validation", messages: rawDetails.filter((detail): detail is string => typeof detail === "string") };
    }

    if (status === 400) {
      return { kind: "malformed" };
    }

    if (status === 429) {
      const retryAfterHeader = error.response?.headers?.["retry-after"];
      const parsed = retryAfterHeader ? Number.parseInt(String(retryAfterHeader), 10) : NaN;

      return {
        kind: "rate_limited",
        retryAfterSeconds: Number.isFinite(parsed) && parsed > 0 ? parsed : null,
      };
    }
  }

  // Statut inconnu, timeout, coupure réseau, 5xx : traité honnêtement comme
  // "réseau" — jamais une fausse affirmation sur l'existence du compte.
  return { kind: "network" };
}
