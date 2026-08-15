import { useState } from "react";
import {
  genererLienPortail,
  revoquerLienPortail,
} from "../api/portailFactureTokensApi";
import { getApiErrorMessage } from "../api/http";

// Portail destinataire (MVP) — le token BRUT n'est renvoyé qu'UNE seule
// fois par l'API (jamais stocké côté backend) : cet état local (`lienUrl`)
// est donc la SEULE trace du lien généré. Il disparaît à la navigation —
// voulu, "minimal" (cf. §5 execution_portail_destinataire_mvp.txt) : pas de
// endpoint "lien actif existant" à interroger, générer à nouveau révoque
// simplement l'ancien lien et en montre un nouveau.
export function usePortailLien(factureId: string | undefined) {
  const [isGenerating, setIsGenerating] = useState(false);
  const [isRevoking, setIsRevoking] = useState(false);
  const [lienUrl, setLienUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function handleGenerer() {
    if (!factureId) {
      return;
    }

    setError(null);
    setIsGenerating(true);

    try {
      const url = await genererLienPortail(factureId);
      setLienUrl(url);
    } catch (apiError) {
      setError(getApiErrorMessage(apiError));
    } finally {
      setIsGenerating(false);
    }
  }

  async function handleRevoquer() {
    if (!factureId) {
      return;
    }

    setError(null);
    setIsRevoking(true);

    try {
      await revoquerLienPortail(factureId);
      setLienUrl(null);
    } catch (apiError) {
      setError(getApiErrorMessage(apiError));
    } finally {
      setIsRevoking(false);
    }
  }

  return {
    isGenerating,
    isRevoking,
    lienUrl,
    error,
    handleGenerer,
    handleRevoquer,
  };
}
