import { useState } from "react";
import { relancerFacture } from "../api/relancesApi";
import { getApiErrorMessage } from "../api/http";
import type { Facture } from "../types/facture";
import type { Relance } from "../types/relance";

// Relances v1a — bouton manuel. Un seul appel : POST puis mise à jour
// immédiate depuis la RÉPONSE (relance + facture à jour renvoyées ensemble,
// cf. RelancesController) — pas de refetch séparé, à la différence des
// paiements (dont les endpoints ne renvoient pas la facture).
export function useRelance(
  factureId: string | undefined,
  onFactureMutated: (facture: Facture) => void,
) {
  const [isSending, setIsSending] = useState(false);
  const [relanceError, setRelanceError] = useState<string | null>(null);
  const [derniereRelance, setDerniereRelance] = useState<Relance | null>(null);

  async function handleRelancer() {
    if (!factureId) {
      return;
    }

    setRelanceError(null);
    setIsSending(true);

    try {
      const result = await relancerFacture(factureId);

      setDerniereRelance(result.relance);
      onFactureMutated(result.facture);
    } catch (apiError) {
      setRelanceError(getApiErrorMessage(apiError));
    } finally {
      setIsSending(false);
    }
  }

  return {
    isSending,
    relanceError,
    derniereRelance,
    handleRelancer,
  };
}
