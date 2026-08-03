import { useEffect, useState, type FormEventHandler } from "react";
import { listEvenementsPaiement } from "../api/evenementsPaiementApi";
import { getApiErrorMessage } from "../api/http";
import {
  annulerPaiement,
  confirmerPaiement,
  createPaiement,
  listPaiements,
} from "../api/paiementsApi";
import type { EvenementPaiement } from "../types/evenementPaiement";
import type { Paiement, PaiementMethodeCode } from "../types/paiement";

function parseDecimal(value: string) {
  const parsed = Number(value.replace(",", "."));

  return Number.isFinite(parsed) ? parsed : 0;
}

// Extrait tel quel de FactureDetailPage (étage C — dette de testabilité
// "cible 5") : état + handlers du bloc paiement, comportement STRICTEMENT
// identique à l'original. `onPaiementMutated` délègue le rafraîchissement de
// la facture (reste_a_payer / statut_encaissement_local) à l'appelant, qui
// seul possède l'état `facture` — ce hook ne connaît que factureId.
export function usePaiements(
  factureId: string | undefined,
  onPaiementMutated: () => void | Promise<void>,
) {
  const [paiements, setPaiements] = useState<Paiement[]>([]);
  const [isLoadingPaiements, setIsLoadingPaiements] = useState(
    Boolean(factureId),
  );
  const [paiementsError, setPaiementsError] = useState<string | null>(null);

  const [montantPaiement, setMontantPaiement] = useState("");
  const [methodePaiement, setMethodePaiement] =
    useState<PaiementMethodeCode>("58");
  const [datePaiement, setDatePaiement] = useState(() =>
    new Date().toISOString().slice(0, 10),
  );
  const [referencePaiement, setReferencePaiement] = useState("");
  const [isRegisteringPaiement, setIsRegisteringPaiement] = useState(false);
  const [paiementError, setPaiementError] = useState<string | null>(null);

  const [confirmingPaiementId, setConfirmingPaiementId] = useState<
    string | null
  >(null);
  const [cancelingPaiementId, setCancelingPaiementId] = useState<
    string | null
  >(null);
  const [paiementToCancel, setPaiementToCancel] = useState<Paiement | null>(
    null,
  );

  const [expandedPaiementId, setExpandedPaiementId] = useState<string | null>(
    null,
  );
  const [paiementEvents, setPaiementEvents] = useState<
    Record<string, EvenementPaiement[]>
  >({});
  const [loadingPaiementEventsId, setLoadingPaiementEventsId] = useState<
    string | null
  >(null);

  useEffect(() => {
    if (!factureId) {
      return;
    }

    let ignore = false;

    void listPaiements(factureId)
      .then((paiementsData) => {
        if (!ignore) {
          setPaiements(paiementsData);
          setPaiementsError(null);
        }
      })
      .catch((apiError) => {
        if (!ignore) {
          setPaiementsError(getApiErrorMessage(apiError));
        }
      })
      .finally(() => {
        if (!ignore) {
          setIsLoadingPaiements(false);
        }
      });

    return () => {
      ignore = true;
    };
  }, [factureId]);

  const handleRegisterPaiement: FormEventHandler<HTMLFormElement> = async (
    event,
  ) => {
    event.preventDefault();

    if (!factureId) {
      setPaiementError("Facture introuvable.");
      return;
    }

    const montant = parseDecimal(montantPaiement);

    if (montant <= 0) {
      setPaiementError("Le montant doit être supérieur à 0.");
      return;
    }

    if (!datePaiement) {
      setPaiementError("La date d’encaissement est requise.");
      return;
    }

    setPaiementError(null);
    setIsRegisteringPaiement(true);

    try {
      // Flux v1 : create (brouillon) PUIS confirmer, en une seule action
      // utilisateur — le paiement apparaît directement confirmé. Aucun
      // endpoint update/discard n'existe (cf. rapport, dette à consigner) :
      // si confirmer échoue, le brouillon résiduel reste visible avec son
      // propre bouton "Confirmer" pour réessayer.
      const brouillon = await createPaiement(factureId, {
        montant,
        methode_code: methodePaiement,
        date_encaissement: datePaiement,
        reference: referencePaiement.trim() || undefined,
      });

      const confirme = await confirmerPaiement(factureId, brouillon.id);

      setPaiements((previous) => [
        confirme,
        ...previous.filter((paiement) => paiement.id !== confirme.id),
      ]);

      await onPaiementMutated();

      setMontantPaiement("");
      setReferencePaiement("");
      setDatePaiement(new Date().toISOString().slice(0, 10));
    } catch (apiError) {
      setPaiementError(getApiErrorMessage(apiError));

      const paiementsData = await listPaiements(factureId).catch(() => null);
      if (paiementsData) {
        setPaiements(paiementsData);
      }
    } finally {
      setIsRegisteringPaiement(false);
    }
  };

  async function handleConfirmPaiement(paiement: Paiement) {
    if (!factureId) {
      return;
    }

    setConfirmingPaiementId(paiement.id);
    setPaiementError(null);

    try {
      const confirme = await confirmerPaiement(factureId, paiement.id);

      setPaiements((previous) =>
        previous.map((item) => (item.id === confirme.id ? confirme : item)),
      );

      await onPaiementMutated();
    } catch (apiError) {
      setPaiementError(getApiErrorMessage(apiError));
    } finally {
      setConfirmingPaiementId(null);
    }
  }

  function handleAskCancelPaiement(paiement: Paiement) {
    setPaiementToCancel(paiement);
  }

  function handleCancelCancelPaiement() {
    setPaiementToCancel(null);
  }

  async function handleConfirmCancelPaiement() {
    if (!factureId || !paiementToCancel) {
      return;
    }

    setCancelingPaiementId(paiementToCancel.id);
    setPaiementError(null);

    try {
      const annule = await annulerPaiement(factureId, paiementToCancel.id);

      setPaiements((previous) =>
        previous.map((item) => (item.id === annule.id ? annule : item)),
      );

      await onPaiementMutated();
      setPaiementToCancel(null);
    } catch (apiError) {
      setPaiementError(getApiErrorMessage(apiError));
      setPaiementToCancel(null);
    } finally {
      setCancelingPaiementId(null);
    }
  }

  async function handleToggleHistoriquePaiement(paiement: Paiement) {
    if (!factureId) {
      return;
    }

    if (expandedPaiementId === paiement.id) {
      setExpandedPaiementId(null);
      return;
    }

    setExpandedPaiementId(paiement.id);

    if (paiementEvents[paiement.id]) {
      return;
    }

    setLoadingPaiementEventsId(paiement.id);

    try {
      const events = await listEvenementsPaiement(factureId, paiement.id);
      setPaiementEvents((previous) => ({ ...previous, [paiement.id]: events }));
    } catch {
      // Sobre (cf. prompt §5) : un historique indisponible n'est pas
      // bloquant, on n'affiche simplement rien de plus.
    } finally {
      setLoadingPaiementEventsId(null);
    }
  }

  return {
    paiements,
    isLoadingPaiements,
    paiementsError,
    montantPaiement,
    setMontantPaiement,
    methodePaiement,
    setMethodePaiement,
    datePaiement,
    setDatePaiement,
    referencePaiement,
    setReferencePaiement,
    isRegisteringPaiement,
    paiementError,
    confirmingPaiementId,
    cancelingPaiementId,
    paiementToCancel,
    expandedPaiementId,
    paiementEvents,
    loadingPaiementEventsId,
    handleRegisterPaiement,
    handleConfirmPaiement,
    handleAskCancelPaiement,
    handleCancelCancelPaiement,
    handleConfirmCancelPaiement,
    handleToggleHistoriquePaiement,
  };
}
