import {
  ArrowLeft,
  CirclePlus,
  FileText,
  Receipt,
  Send,
  ShieldCheck,
  Trash2,
  Wallet,
} from "lucide-react";
import { useEffect, useState, type FormEventHandler } from "react";
import { Link, useParams } from "react-router-dom";
import {
  emettreFacture,
  getConformiteFacture,
  getFacture,
  getFacturePdfUrl,
  getFactureXmlUrl,
} from "../api/facturesApi";
import { listAvoirs, sommeAvoirsDejaEmis } from "../api/avoirsApi";
import { listEvenementsFacture } from "../api/evenementsFactureApi";
import { listEvenementsPaiement } from "../api/evenementsPaiementApi";
import { getApiErrorMessage } from "../api/http";
import {
  createLigneFacture,
  deleteLigneFacture,
  listLignesFacture,
} from "../api/lignesFactureApi";
import {
  annulerPaiement,
  confirmerPaiement,
  createPaiement,
  listPaiements,
} from "../api/paiementsApi";
import {
  getRequiresReviewCount,
  getTransmissionFromError,
  listTransmissionsPa,
  relancerTransmissionPa,
  simulerTransmissionPa,
  synchroniserTransmissionPa,
} from "../api/transmissionPaApi";
import { ConfirmModal } from "../components/ConfirmModal";
import { InvoiceDetailHeader } from "../components/InvoiceDetailHeader";
import { InvoiceEventHistory } from "../components/InvoiceEventHistory";
import { InvoiceLifecycleTimeline } from "../components/InvoiceLifecycleTimeline";
import { InvoiceTransmissionSection } from "../components/InvoiceTransmissionSection";
import type { Avoir } from "../types/avoir";
import type { ConformiteResult } from "../types/conformite";
import type { EvenementFacture } from "../types/evenementFacture";
import type { EvenementPaiement } from "../types/evenementPaiement";
import type { Facture, StatutEncaissementLocal } from "../types/facture";
import type { LigneFacture } from "../types/ligneFacture";
import { MOYENS_PAIEMENT, type Paiement, type PaiementMethodeCode } from "../types/paiement";
import type { PaSyncResult, TransmissionPa } from "../types/transmissionPa";

const STATUT_ENCAISSEMENT_LABELS: Record<StatutEncaissementLocal, string> = {
  non_payee: "Non payée",
  partielle: "Partielle",
  soldee: "Soldée",
};

const PAIEMENT_STATUT_LABELS: Record<Paiement["statut"], string> = {
  brouillon: "Brouillon",
  confirme: "Confirmé",
  annule: "Annulé",
};

// Miroir de FactureStatusTransitionPolicy::TERMINAUX (backend) : une facture
// dans un de ces statuts ne peut plus être synchronisée.
const FACTURE_STATUTS_TERMINAUX = ["encaissee", "refusee", "annulee", "archivee"];

const CLIENT_TYPE_LABELS: Record<"entreprise" | "particulier" | "public", string> = {
  entreprise: "Entreprise",
  particulier: "Particulier",
  public: "Public",
};

function resolveClientMeta(client: Facture["client"]) {
  if (!client) {
    return null;
  }

  if (client.email) {
    return client.email;
  }

  if (client.ville && client.pays) {
    return `${client.ville}, ${client.pays}`;
  }

  if (client.ville) {
    return client.ville;
  }

  if (client.type) {
    return CLIENT_TYPE_LABELS[client.type];
  }

  if (client.siret) {
    return `SIRET ${client.siret}`;
  }

  return null;
}

export function FactureDetailPage() {
  const { id } = useParams<{ id: string }>();

  const [facture, setFacture] = useState<Facture | null>(null);
  const [lignes, setLignes] = useState<LigneFacture[]>([]);
  const [conformite, setConformite] = useState<ConformiteResult | null>(null);

  const [designation, setDesignation] = useState("");
  const [quantite, setQuantite] = useState("1");
  const [prixUnitaireHt, setPrixUnitaireHt] = useState("");
  const [tauxTva, setTauxTva] = useState("20");

  const [isLoading, setIsLoading] = useState(Boolean(id));
  const [isAddingLine, setIsAddingLine] = useState(false);
  const [deletingLineId, setDeletingLineId] = useState<string | null>(null);
  const [lineToDelete, setLineToDelete] = useState<LigneFacture | null>(null);
  const [isCheckingConformite, setIsCheckingConformite] = useState(false);
  const [isEmitting, setIsEmitting] = useState(false);
  const [isEmitConfirmOpen, setIsEmitConfirmOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [events, setEvents] = useState<EvenementFacture[]>([]);
  const [isLoadingEvents, setIsLoadingEvents] = useState(Boolean(id));
  const [eventsError, setEventsError] = useState<string | null>(null);

  const [transmissions, setTransmissions] = useState<TransmissionPa[]>([]);
  const [isLoadingTransmissions, setIsLoadingTransmissions] = useState(
    Boolean(id),
  );
  const [transmissionsError, setTransmissionsError] = useState<string | null>(
    null,
  );
  const [isTransmitting, setIsTransmitting] = useState(false);
  const [isTransmitConfirmOpen, setIsTransmitConfirmOpen] = useState(false);

  const [isSynchronizing, setIsSynchronizing] = useState(false);
  const [syncResult, setSyncResult] = useState<PaSyncResult | null>(null);
  const [syncError, setSyncError] = useState<string | null>(null);

  const [requiresReviewCount, setRequiresReviewCount] = useState<
    number | null
  >(null);
  const [isRelaunching, setIsRelaunching] = useState(false);
  const [relaunchError, setRelaunchError] = useState<string | null>(null);

  // V1.2d — navigation croisée + garde-fou cumulé : les avoirs de CETTE
  // facture, pour afficher le total déjà crédité et le reste créditable.
  const [avoirs, setAvoirs] = useState<Avoir[]>([]);
  const [isLoadingAvoirs, setIsLoadingAvoirs] = useState(Boolean(id));
  const [avoirsError, setAvoirsError] = useState<string | null>(null);

  // Paiements v1 étage C.
  const [paiements, setPaiements] = useState<Paiement[]>([]);
  const [isLoadingPaiements, setIsLoadingPaiements] = useState(Boolean(id));
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

  const isDraft = facture?.statut === "brouillon";

  const derniereTransmission = transmissions[0] ?? null;
  const canSynchronize =
    Boolean(facture) &&
    derniereTransmission?.statut === "depose" &&
    !FACTURE_STATUTS_TERMINAUX.includes(facture?.statut ?? "");

  // B2 : on n'affiche les liens PDF/XML que si le backend confirme leur présence.
  const hasPdf = Boolean(facture?.pdf_url);
  const hasXml = Boolean(facture?.xml_url);

  // Problème 2 — solde après avoirs : DÉRIVÉ uniquement (jamais stocké sur la
  // facture, jamais un remplacement du Total TTC légal affiché par
  // InvoiceDetailHeader ci-dessous, qui reste intact). Seuls les avoirs NON
  // brouillon réduisent le dû — sommeAvoirsDejaEmis (V1.2d) filtre déjà
  // exactement ainsi, réutilisée telle quelle plutôt que réécrite.
  const montantAvoirsEmis = sommeAvoirsDejaEmis(avoirs);
  const resteDu = Math.max(0, toNumber(facture?.total_ttc) - montantAvoirsEmis);

  // Paiements v1 étage C — reste_a_payer et statut_encaissement_local sont
  // DÉRIVÉS par le backend (PaiementSyntheseService), jamais recalculés ici.
  // "Payé" seul n'est pas exposé tel quel par l'API : il se déduit de deux
  // valeurs déjà fournies par le backend (reste dû après avoirs − reste à
  // payer), exactement comme "Reste dû" lui-même se déduit déjà de
  // total_ttc et des avoirs ci-dessus — aucun nouvel arrondi introduit.
  const resteAPayer = toNumber(facture?.reste_a_payer);
  const montantPaye = Math.max(0, resteDu - resteAPayer);
  const statutEncaissementLocal = facture?.statut_encaissement_local ?? null;

  const canEmit =
    Boolean(facture) &&
    isDraft &&
    lignes.length > 0 &&
    conformite?.conforme === true;

  useEffect(() => {
    if (!id) {
      return;
    }

    let ignore = false;

    void Promise.all([getFacture(id), listLignesFacture(id)])
      .then(([factureData, lignesData]) => {
        if (ignore) {
          return;
        }

        setFacture(factureData);
        setLignes(lignesData);
        setConformite(null);
        setError(null);
      })
      .catch((apiError) => {
        if (ignore) {
          return;
        }

        setError(getApiErrorMessage(apiError));
      })
      .finally(() => {
        if (ignore) {
          return;
        }

        setIsLoading(false);
      });

    return () => {
      ignore = true;
    };
  }, [id]);

  useEffect(() => {
    if (!id) {
      return;
    }

    let ignore = false;

    void listEvenementsFacture(id)
      .then((eventsData) => {
        if (ignore) {
          return;
        }

        setEvents(eventsData);
        setEventsError(null);
      })
      .catch((apiError) => {
        if (ignore) {
          return;
        }

        setEventsError(getApiErrorMessage(apiError));
      })
      .finally(() => {
        if (ignore) {
          return;
        }

        setIsLoadingEvents(false);
      });

    return () => {
      ignore = true;
    };
  }, [id]);

  // B3.2 — badge persistant : chargé au montage de la page, indépendamment
  // de tout clic sur "Vérifier maintenant". Scopé Current.organisation côté
  // backend, pas cette facture précise (cf. reconnaissance B3.2).
  useEffect(() => {
    let ignore = false;

    void getRequiresReviewCount()
      .then((count) => {
        if (!ignore) {
          setRequiresReviewCount(count);
        }
      })
      .catch(() => {
        if (!ignore) {
          setRequiresReviewCount(null);
        }
      });

    return () => {
      ignore = true;
    };
  }, []);

  useEffect(() => {
    if (!id) {
      return;
    }

    let ignore = false;

    void listTransmissionsPa(id)
      .then((transmissionsData) => {
        if (ignore) {
          return;
        }

        setTransmissions(transmissionsData);
        setTransmissionsError(null);
      })
      .catch((apiError) => {
        if (ignore) {
          return;
        }

        setTransmissionsError(getApiErrorMessage(apiError));
      })
      .finally(() => {
        if (ignore) {
          return;
        }

        setIsLoadingTransmissions(false);
      });

    return () => {
      ignore = true;
    };
  }, [id]);

  useEffect(() => {
    if (!id) {
      return;
    }

    let ignore = false;

    void listAvoirs(id)
      .then((avoirsData) => {
        if (!ignore) {
          setAvoirs(avoirsData);
          setAvoirsError(null);
        }
      })
      .catch((apiError) => {
        if (!ignore) {
          setAvoirsError(getApiErrorMessage(apiError));
        }
      })
      .finally(() => {
        if (!ignore) {
          setIsLoadingAvoirs(false);
        }
      });

    return () => {
      ignore = true;
    };
  }, [id]);

  useEffect(() => {
    if (!id) {
      return;
    }

    let ignore = false;

    void listPaiements(id)
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
  }, [id]);

  const handleAddLine: FormEventHandler<HTMLFormElement> = async (event) => {
    event.preventDefault();

    if (!facture) {
      setError("Facture introuvable.");
      return;
    }

    if (!isDraft) {
      setError("Cette facture est émise. Elle ne peut plus être modifiée.");
      return;
    }

    const parsedQuantite = parseDecimal(quantite);
    const parsedPrixUnitaireHt = parseDecimal(prixUnitaireHt);
    const parsedTauxTva = parseDecimal(tauxTva);

    if (designation.trim().length < 2) {
      setError("La désignation doit contenir au moins 2 caractères.");
      return;
    }

    if (parsedQuantite <= 0) {
      setError("La quantité doit être supérieure à 0.");
      return;
    }

    if (parsedPrixUnitaireHt <= 0) {
      setError("Le prix unitaire HT doit être supérieur à 0.");
      return;
    }

    if (parsedTauxTva < 0) {
      setError("Le taux de TVA doit être positif ou nul.");
      return;
    }

    setError(null);
    setIsAddingLine(true);

    try {
      const updatedFacture = await createLigneFacture(facture.id, {
        designation: designation.trim(),
        quantite: parsedQuantite,
        prix_unitaire_ht: parsedPrixUnitaireHt,
        taux_tva: parsedTauxTva,
        position: lignes.length + 1,
      });

      const updatedLignes = await listLignesFacture(facture.id);

      setFacture(updatedFacture);
      setLignes(updatedLignes);
      setConformite(null);

      setDesignation("");
      setQuantite("1");
      setPrixUnitaireHt("");
      setTauxTva("20");
    } catch (apiError) {
      setError(getApiErrorMessage(apiError));
    } finally {
      setIsAddingLine(false);
    }
  };

  function handleAskDeleteLine(ligne: LigneFacture) {
    if (!facture || !isDraft) {
      setError("Seules les lignes d’un brouillon peuvent être supprimées.");
      return;
    }

    setLineToDelete(ligne);
  }

  function handleCancelDeleteLine() {
    if (deletingLineId) {
      return;
    }

    setLineToDelete(null);
  }

  async function handleConfirmDeleteLine() {
    if (!facture || !lineToDelete) {
      return;
    }

    if (!isDraft) {
      setError("Seules les lignes d’un brouillon peuvent être supprimées.");
      setLineToDelete(null);
      return;
    }

    setDeletingLineId(lineToDelete.id);
    setError(null);

    try {
      const updatedFacture = await deleteLigneFacture(lineToDelete.id);
      const updatedLignes = await listLignesFacture(facture.id);

      setFacture(updatedFacture);
      setLignes(updatedLignes);
      setConformite(null);
      setLineToDelete(null);
    } catch (apiError) {
      setError(getApiErrorMessage(apiError));
      setLineToDelete(null);
    } finally {
      setDeletingLineId(null);
    }
  }

  async function handleCheckConformite() {
    if (!facture) {
      setError("Facture introuvable.");
      return;
    }

    if (lignes.length === 0) {
      setError("Ajoutez au moins une ligne avant de vérifier la conformité.");
      return;
    }

    setError(null);
    setIsCheckingConformite(true);

    try {
      const result = await getConformiteFacture(facture.id);
      setConformite(result);
    } catch (apiError) {
      setError(getApiErrorMessage(apiError));
    } finally {
      setIsCheckingConformite(false);
    }
  }

  async function handleEmitFacture() {
    if (!facture) {
      setError("Facture introuvable.");
      return;
    }

    if (!conformite?.conforme) {
      setError("Vérifiez la conformité avant d’émettre la facture.");
      return;
    }

    setError(null);
    setIsEmitting(true);

    try {
      const emittedFacture = await emettreFacture(facture.id);
      const updatedLignes = await listLignesFacture(facture.id);

      setFacture(emittedFacture);
      setLignes(updatedLignes);
      setConformite(null);
    } catch (apiError) {
      setError(getApiErrorMessage(apiError));
    } finally {
      setIsEmitting(false);
    }
  }

  const handleConfirmEmitFacture = async () => {
    await handleEmitFacture();
    setIsEmitConfirmOpen(false);
  };

  function upsertTransmission(
    previous: TransmissionPa[],
    transmission: TransmissionPa,
  ) {
    const autres = previous.filter((item) => item.id !== transmission.id);

    return [ transmission, ...autres ];
  }

  async function handleSimulateTransmission() {
    if (!facture) {
      setError("Facture introuvable.");
      return;
    }

    setError(null);
    setIsTransmitting(true);

    try {
      const transmission = await simulerTransmissionPa(facture.id);

      setTransmissions((previous) => upsertTransmission(previous, transmission));

      const updatedFacture = await getFacture(facture.id);
      setFacture(updatedFacture);
    } catch (apiError) {
      const transmissionEnErreur = getTransmissionFromError(apiError);

      if (transmissionEnErreur) {
        setTransmissions((previous) =>
          upsertTransmission(previous, transmissionEnErreur),
        );
      } else {
        setError(getApiErrorMessage(apiError));
      }
    } finally {
      setIsTransmitting(false);
    }
  }

  const handleConfirmTransmit = async () => {
    await handleSimulateTransmission();
    setIsTransmitConfirmOpen(false);
  };

  async function handleSynchronize() {
    if (!facture) {
      return;
    }

    setSyncError(null);
    setIsSynchronizing(true);

    try {
      const result = await synchroniserTransmissionPa(facture.id);

      setSyncResult(result);
      setTransmissions((previous) =>
        upsertTransmission(previous, result.transmission),
      );

      if (result.resultat === "applied") {
        const [updatedFacture, updatedEvents] = await Promise.all([
          getFacture(facture.id),
          listEvenementsFacture(facture.id),
        ]);

        setFacture(updatedFacture);
        setEvents(updatedEvents);
      }
    } catch (apiError) {
      setSyncResult(null);
      setSyncError(getApiErrorMessage(apiError));
    } finally {
      setIsSynchronizing(false);
    }
  }

  async function handleRelaunch() {
    if (!facture) {
      return;
    }

    setRelaunchError(null);
    setIsRelaunching(true);

    try {
      const transmission = await relancerTransmissionPa(facture.id);

      setTransmissions((previous) =>
        upsertTransmission(previous, transmission),
      );
    } catch (apiError) {
      setRelaunchError(getApiErrorMessage(apiError));
    } finally {
      setIsRelaunching(false);
    }
  }

  function handleOpenPdf() {
    if (!facture || !hasPdf) {
      return;
    }

    window.open(getFacturePdfUrl(facture.id), "_blank", "noopener,noreferrer");
  }

  function handleOpenXml() {
    if (!facture || !hasXml) {
      return;
    }

    window.open(getFactureXmlUrl(facture.id), "_blank", "noopener,noreferrer");
  }

  // Refetch de la facture après toute mutation d'un paiement : reste_a_payer
  // et statut_encaissement_local sont dérivés côté backend, la ligne "Reste
  // à payer" en tête de page ne se rafraîchit pas sinon (ce projet n'utilise
  // pas de cache TanStack Query — un refetch manuel joue le même rôle).
  async function refreshFactureApresPaiement(factureId: string) {
    try {
      const updatedFacture = await getFacture(factureId);
      setFacture(updatedFacture);
    } catch {
      // Sobre : un échec de rafraîchissement n'annule pas l'action déjà
      // faite, la page réaffichera l'état à jour au prochain chargement.
    }
  }

  const handleRegisterPaiement: FormEventHandler<HTMLFormElement> = async (
    event,
  ) => {
    event.preventDefault();

    if (!facture) {
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
      const brouillon = await createPaiement(facture.id, {
        montant,
        methode_code: methodePaiement,
        date_encaissement: datePaiement,
        reference: referencePaiement.trim() || undefined,
      });

      const confirme = await confirmerPaiement(facture.id, brouillon.id);

      setPaiements((previous) => [
        confirme,
        ...previous.filter((paiement) => paiement.id !== confirme.id),
      ]);

      await refreshFactureApresPaiement(facture.id);

      setMontantPaiement("");
      setReferencePaiement("");
      setDatePaiement(new Date().toISOString().slice(0, 10));
    } catch (apiError) {
      setPaiementError(getApiErrorMessage(apiError));

      const paiementsData = await listPaiements(facture.id).catch(() => null);
      if (paiementsData) {
        setPaiements(paiementsData);
      }
    } finally {
      setIsRegisteringPaiement(false);
    }
  };

  async function handleConfirmPaiement(paiement: Paiement) {
    if (!facture) {
      return;
    }

    setConfirmingPaiementId(paiement.id);
    setPaiementError(null);

    try {
      const confirme = await confirmerPaiement(facture.id, paiement.id);

      setPaiements((previous) =>
        previous.map((item) => (item.id === confirme.id ? confirme : item)),
      );

      await refreshFactureApresPaiement(facture.id);
    } catch (apiError) {
      setPaiementError(getApiErrorMessage(apiError));
    } finally {
      setConfirmingPaiementId(null);
    }
  }

  function handleAskCancelPaiement(paiement: Paiement) {
    setPaiementToCancel(paiement);
  }

  async function handleConfirmCancelPaiement() {
    if (!facture || !paiementToCancel) {
      return;
    }

    setCancelingPaiementId(paiementToCancel.id);
    setPaiementError(null);

    try {
      const annule = await annulerPaiement(facture.id, paiementToCancel.id);

      setPaiements((previous) =>
        previous.map((item) => (item.id === annule.id ? annule : item)),
      );

      await refreshFactureApresPaiement(facture.id);
      setPaiementToCancel(null);
    } catch (apiError) {
      setPaiementError(getApiErrorMessage(apiError));
      setPaiementToCancel(null);
    } finally {
      setCancelingPaiementId(null);
    }
  }

  async function handleToggleHistoriquePaiement(paiement: Paiement) {
    if (!facture) {
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
      const events = await listEvenementsPaiement(facture.id, paiement.id);
      setPaiementEvents((previous) => ({ ...previous, [paiement.id]: events }));
    } catch {
      // Sobre (cf. prompt §5) : un historique indisponible n'est pas
      // bloquant, on n'affiche simplement rien de plus.
    } finally {
      setLoadingPaiementEventsId(null);
    }
  }

  return (
    <section className="new-invoice-page">
      <div className="page-heading">
        <div>
          <span className="page-kicker">Détail facture</span>
          <h1>Détail de la facture</h1>
          <p>
            Consultez le document, modifiez les brouillons et accédez aux
            fichiers PDF/XML après émission.
          </p>
        </div>

        <Link to="/app/factures" className="secondary-btn">
          <ArrowLeft size={16} />
          Retour liste
        </Link>
      </div>

      {isLoading && (
        <div className="state-card">Chargement de la facture...</div>
      )}

      {!isLoading && facture && (
        <InvoiceDetailHeader
          invoiceNumber={facture.numero}
          status={facture.statut}
          clientName={facture.client?.raison_sociale ?? null}
          clientMeta={resolveClientMeta(facture.client)}
          totalHt={toNumber(facture.total_ht)}
          totalTva={toNumber(facture.total_tva)}
          totalTtc={toNumber(facture.total_ttc)}
          currency={facture.devise}
          invoiceDate={facture.created_at ?? null}
          emittedAt={facture.emise_at}
          dueDate={facture.date_echeance}
          hasPdf={hasPdf}
          hasXml={hasXml}
          onOpenPdf={handleOpenPdf}
          onOpenXml={handleOpenXml}
        />
      )}

      {!isLoading && facture && facture.statut !== "brouillon" && (
        <div className="invoice-builder-card">
          <p className="hint-text">
            Solde de gestion — le document facture ci-dessus reste inchangé
            (valeur légale {formatCurrency(toNumber(facture.total_ttc))}), de
            même que son statut de cycle de vie ({facture.statut}).
          </p>

          <div className="invoice-totals-card">
            <div>
              <span>Total facturé (TTC)</span>
              <strong>{formatCurrency(toNumber(facture.total_ttc))}</strong>
            </div>

            <div>
              <span>Avoirs émis</span>
              <strong>− {formatCurrency(montantAvoirsEmis)}</strong>
            </div>

            <div className="total-ttc-row">
              <span>Reste dû</span>
              <strong>{formatCurrency(resteDu)}</strong>
            </div>

            <div>
              <span>Payé</span>
              <strong>{formatCurrency(montantPaye)}</strong>
            </div>

            <div className="total-ttc-row">
              <span>
                Reste à payer
                {statutEncaissementLocal && (
                  <span className="badge-paiement" style={{ marginLeft: 8 }}>
                    {STATUT_ENCAISSEMENT_LABELS[statutEncaissementLocal]}
                  </span>
                )}
              </span>
              <strong>{formatCurrency(resteAPayer)}</strong>
            </div>
          </div>
        </div>
      )}

      {error && <div className="state-card error">{error}</div>}

      {!isLoading && !facture && !error && (
        <div className="state-card">Facture introuvable.</div>
      )}

      {!isLoading && facture && (
        <InvoiceLifecycleTimeline
          status={facture.statut}
          createdAt={facture.created_at}
          emittedAt={facture.emise_at}
          invoiceNumber={facture.numero}
        />
      )}

      {!isLoading && facture && (
        <InvoiceEventHistory
          events={events}
          isLoading={isLoadingEvents}
          error={eventsError}
        />
      )}

      {!isLoading &&
        facture &&
        (facture.statut === "emise" || transmissions.length > 0) && (
          <InvoiceTransmissionSection
            transmissions={transmissions}
            isLoading={isLoadingTransmissions}
            error={transmissionsError}
            isTransmitting={isTransmitting}
            onSimulate={() => setIsTransmitConfirmOpen(true)}
            canSynchronize={canSynchronize}
            isSynchronizing={isSynchronizing}
            syncResult={syncResult}
            syncError={syncError}
            onSynchronize={() => {
              void handleSynchronize();
            }}
            requiresReviewCount={requiresReviewCount}
            isRelaunching={isRelaunching}
            relaunchError={relaunchError}
            onRelaunch={() => {
              void handleRelaunch();
            }}
          />
        )}

      {!isLoading && facture && facture.statut !== "brouillon" && (
        <section
          className="invoice-transmission-section"
          aria-labelledby="facture-avoirs-title"
        >
          <div className="invoice-transmission-section__header">
            <div className="invoice-transmission-section__heading-row">
              <h2 id="facture-avoirs-title" className="invoice-transmission-section__title">
                Avoirs
              </h2>
            </div>
            <p className="invoice-transmission-section__subtitle">
              {formatCurrency(montantAvoirsEmis)} déjà crédités sur{" "}
              {formatCurrency(toNumber(facture.total_ttc))} TTC — reste{" "}
              {formatCurrency(resteDu)} créditables.
            </p>
          </div>

          {isLoadingAvoirs && (
            <p className="invoice-transmission-section__loading">
              Chargement des avoirs...
            </p>
          )}

          {!isLoadingAvoirs && avoirsError && (
            <p className="invoice-transmission-section__error">{avoirsError}</p>
          )}

          {!isLoadingAvoirs && !avoirsError && avoirs.length === 0 && (
            <p className="invoice-transmission-section__empty">
              Aucun avoir n’a encore été créé pour cette facture.
            </p>
          )}

          {!isLoadingAvoirs && avoirs.length > 0 && (
            <div className="invoice-lines-table">
              <div className="invoice-lines-header">
                <span>Numéro</span>
                <span>Motif</span>
                <span>Statut</span>
                <span>Montant TTC</span>
                <span>Type</span>
              </div>

              {avoirs.map((avoir) => (
                <Link
                  key={avoir.id}
                  to={`/app/avoirs/${avoir.id}`}
                  className="invoice-lines-row"
                  style={{ textDecoration: "none", cursor: "pointer" }}
                >
                  <strong>{avoir.numero ?? "Brouillon"}</strong>
                  <span>{avoir.motif}</span>
                  <span>{avoir.statut}</span>
                  <strong>{formatCurrency(toNumber(avoir.total_ttc))}</strong>
                  <span className="badge-avoir">Avoir</span>
                </Link>
              ))}
            </div>
          )}

          <div className="invoice-actions-row">
            <Link
              to={`/app/factures/${facture.id}/avoirs/nouveau`}
              className="avoir-btn"
            >
              <Receipt size={16} />
              Créer un avoir
            </Link>
          </div>
        </section>
      )}

      {!isLoading && facture && facture.statut !== "brouillon" && (
        <section
          className="invoice-transmission-section"
          aria-labelledby="facture-paiements-title"
        >
          <div className="invoice-transmission-section__header">
            <div className="invoice-transmission-section__heading-row">
              <h2
                id="facture-paiements-title"
                className="invoice-transmission-section__title"
              >
                Paiements
              </h2>
            </div>
            <p className="invoice-transmission-section__subtitle">
              {formatCurrency(montantPaye)} encaissés sur{" "}
              {formatCurrency(resteDu)} dus après avoirs — reste{" "}
              {formatCurrency(resteAPayer)} à payer.
            </p>
          </div>

          {isLoadingPaiements && (
            <p className="invoice-transmission-section__loading">
              Chargement des paiements...
            </p>
          )}

          {!isLoadingPaiements && paiementsError && (
            <p className="invoice-transmission-section__error">
              {paiementsError}
            </p>
          )}

          {!isLoadingPaiements && !paiementsError && paiements.length === 0 && (
            <p className="invoice-transmission-section__empty">
              Aucun paiement n’a encore été enregistré pour cette facture.
            </p>
          )}

          {!isLoadingPaiements && paiements.length > 0 && (
            <div className="invoice-lines-table">
              <div className="invoice-lines-header">
                <span>Date</span>
                <span>Moyen</span>
                <span>Référence</span>
                <span>Montant</span>
                <span>Statut</span>
              </div>

              {paiements.map((paiement) => (
                <div key={paiement.id}>
                  <div
                    className={`invoice-lines-row ${
                      paiement.statut === "annule" ? "paiement-row--annule" : ""
                    }`}
                  >
                    <span>{formatDate(paiement.date_encaissement)}</span>
                    <span>{paiement.methode_libelle}</span>
                    <span>{paiement.reference || "—"}</span>
                    <strong>{formatCurrency(toNumber(paiement.montant))}</strong>
                    <span
                      className={`badge-paiement ${
                        paiement.statut === "annule"
                          ? "badge-paiement--annule"
                          : ""
                      }`}
                    >
                      {PAIEMENT_STATUT_LABELS[paiement.statut]}
                    </span>
                  </div>

                  <div className="invoice-actions-row">
                    <button
                      type="button"
                      className="table-action-btn"
                      onClick={() => {
                        void handleToggleHistoriquePaiement(paiement);
                      }}
                    >
                      {expandedPaiementId === paiement.id
                        ? "Masquer l’historique"
                        : "Historique"}
                    </button>

                    {paiement.statut === "brouillon" && (
                      <button
                        type="button"
                        className="paiement-btn"
                        disabled={confirmingPaiementId === paiement.id}
                        onClick={() => {
                          void handleConfirmPaiement(paiement);
                        }}
                      >
                        {confirmingPaiementId === paiement.id
                          ? "Confirmation..."
                          : "Confirmer"}
                      </button>
                    )}

                    {paiement.statut === "confirme" && (
                      <button
                        type="button"
                        className="table-action-btn danger"
                        disabled={cancelingPaiementId === paiement.id}
                        onClick={() => handleAskCancelPaiement(paiement)}
                      >
                        {cancelingPaiementId === paiement.id
                          ? "Annulation..."
                          : "Annuler"}
                      </button>
                    )}
                  </div>

                  {expandedPaiementId === paiement.id && (
                    <div className="state-card">
                      {loadingPaiementEventsId === paiement.id
                        ? "Chargement de l’historique..."
                        : (paiementEvents[paiement.id]?.length ?? 0) > 0
                          ? (
                            <ul>
                              {paiementEvents[paiement.id].map((evenement) => (
                                <li key={evenement.id}>
                                  {formatDate(evenement.created_at)} —{" "}
                                  {PAIEMENT_STATUT_LABELS[evenement.statut]}
                                  {evenement.actor
                                    ? ` (${evenement.actor.display_name})`
                                    : ""}
                                </li>
                              ))}
                            </ul>
                          )
                          : "Aucun événement."}
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}

          <form className="line-form" onSubmit={handleRegisterPaiement}>
            <div className="line-form-grid">
              <label>
                Montant
                <input
                  type="number"
                  step="0.01"
                  min="0.01"
                  value={montantPaiement}
                  placeholder="500"
                  onChange={(event) => setMontantPaiement(event.target.value)}
                />
              </label>

              <label>
                Moyen
                <select
                  value={methodePaiement}
                  onChange={(event) =>
                    setMethodePaiement(
                      event.target.value as PaiementMethodeCode,
                    )
                  }
                >
                  {MOYENS_PAIEMENT.map((moyen) => (
                    <option key={moyen.code} value={moyen.code}>
                      {moyen.libelle}
                    </option>
                  ))}
                </select>
              </label>

              <label>
                Date d’encaissement
                <input
                  type="date"
                  value={datePaiement}
                  onChange={(event) => setDatePaiement(event.target.value)}
                />
              </label>

              <label>
                Référence (optionnel)
                <input
                  type="text"
                  value={referencePaiement}
                  placeholder="VIR-2026-001"
                  onChange={(event) =>
                    setReferencePaiement(event.target.value)
                  }
                />
              </label>
            </div>

            <div className="invoice-actions-row">
              <button
                type="submit"
                className="paiement-btn"
                disabled={isRegisteringPaiement}
              >
                <Wallet size={16} />
                {isRegisteringPaiement
                  ? "Enregistrement..."
                  : "Enregistrer un paiement"}
              </button>
            </div>
          </form>

          {paiementError && (
            <p className="invoice-transmission-section__error">
              {paiementError}
            </p>
          )}
        </section>
      )}

      {!isLoading && facture && (
        <div className="invoice-builder-card">
          <div className="draft-preview-card">
            <div className="document-icon">
              <FileText size={18} />
            </div>

            <div>
              <strong>{formatFactureFormat(facture.format)}</strong>
              <span>Échéance : {formatDate(facture.date_echeance)}</span>
            </div>
          </div>

          {isDraft && (
            <form className="line-form" onSubmit={handleAddLine}>
              <div className="line-form-grid">
                <label>
                  Désignation
                  <input
                    type="text"
                    value={designation}
                    placeholder="Ex : Développement module facture"
                    onChange={(event) => setDesignation(event.target.value)}
                  />
                </label>

                <label>
                  Qté
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    value={quantite}
                    onChange={(event) => setQuantite(event.target.value)}
                  />
                </label>

                <label>
                  PU HT
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    value={prixUnitaireHt}
                    placeholder="1200"
                    onChange={(event) =>
                      setPrixUnitaireHt(event.target.value)
                    }
                  />
                </label>

                <label>
                  TVA %
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    value={tauxTva}
                    onChange={(event) => setTauxTva(event.target.value)}
                  />
                </label>
              </div>

              <button
                type="submit"
                className="primary-btn create-draft-btn"
                disabled={isAddingLine}
              >
                <CirclePlus size={16} />
                {isAddingLine ? "Ajout..." : "Ajouter la ligne"}
              </button>
            </form>
          )}

          {!isDraft && (
            <div className="state-card">
              Facture émise : les lignes ne sont plus modifiables. Toute
              correction passera plus tard par un avoir.
            </div>
          )}

          {lignes.length === 0 && (
            <div className="state-card">
              Aucune ligne pour le moment. Ajoutez une première prestation.
            </div>
          )}

          {lignes.length > 0 && (
            <div className="invoice-lines-table detail-lines-table">
              <div className="invoice-lines-header">
                <span>Désignation</span>
                <span>Qté</span>
                <span>PU HT</span>
                <span>TVA</span>
                <span>Total TTC</span>
                {isDraft && <span>Action</span>}
              </div>

              {lignes.map((ligne) => (
                <div className="invoice-lines-row" key={ligne.id}>
                  <strong>{ligne.designation}</strong>
                  <span>{formatQuantity(ligne.quantite)}</span>
                  <span>{formatCurrency(toNumber(ligne.prix_unitaire_ht))}</span>
                  <span>{formatPercent(ligne.taux_tva)}</span>
                  <strong>{formatCurrency(toNumber(ligne.total_ttc))}</strong>

                  {isDraft && (
                    <button
                      type="button"
                      className="table-action-btn danger"
                      disabled={deletingLineId === ligne.id}
                      onClick={() => handleAskDeleteLine(ligne)}
                    >
                      <Trash2 size={14} />
                      {deletingLineId === ligne.id
                        ? "Suppression..."
                        : "Supprimer"}
                    </button>
                  )}
                </div>
              ))}
            </div>
          )}

          <div className="invoice-totals-card">
            <div>
              <span>Total HT</span>
              <strong>{formatCurrency(toNumber(facture.total_ht))}</strong>
            </div>

            <div>
              <span>TVA</span>
              <strong>{formatCurrency(toNumber(facture.total_tva))}</strong>
            </div>

            <div className="total-ttc-row">
              <span>Total TTC</span>
              <strong>{formatCurrency(toNumber(facture.total_ttc))}</strong>
            </div>
          </div>

          {isDraft && (
            <div className="invoice-actions-row">
              <button
                type="button"
                className="secondary-btn"
                disabled={isCheckingConformite || lignes.length === 0}
                onClick={handleCheckConformite}
              >
                <ShieldCheck size={16} />
                {isCheckingConformite
                  ? "Vérification..."
                  : "Vérifier conformité"}
              </button>
            </div>
          )}

          {isDraft && conformite && (
            <div
              className={`conformite-result-card ${
                conformite.conforme ? "success" : "error"
              }`}
            >
              <strong>
                {conformite.conforme
                  ? "Facture conforme"
                  : "Facture non conforme"}
              </strong>

              {getConformiteErrors(conformite).length > 0 && (
                <ul>
                  {getConformiteErrors(conformite).map((message, index) => (
                    <li key={`${message}-${index}`}>{message}</li>
                  ))}
                </ul>
              )}

              {getConformiteWarnings(conformite).length > 0 && (
                <ul>
                  {getConformiteWarnings(conformite).map((message, index) => (
                    <li key={`${message}-${index}`}>{message}</li>
                  ))}
                </ul>
              )}

              {conformite.conforme &&
                getConformiteErrors(conformite).length === 0 &&
                getConformiteWarnings(conformite).length === 0 && (
                  <p>Aucune erreur bloquante détectée.</p>
                )}
            </div>
          )}

          {canEmit && (
            <div className="invoice-actions-row">
              <button
                type="button"
                className="primary-btn"
                disabled={isEmitting}
                onClick={() => setIsEmitConfirmOpen(true)}
              >
                <Send size={16} aria-hidden="true" />
                {isEmitting ? "Émission..." : "Émettre"}
              </button>
            </div>
          )}
        </div>
      )}

      <ConfirmModal
        open={Boolean(lineToDelete)}
        title="Supprimer cette ligne ?"
        message={
          lineToDelete
            ? `La ligne "${lineToDelete.designation}" sera supprimée du brouillon. Les totaux de la facture seront recalculés.`
            : ""
        }
        confirmLabel={deletingLineId ? "Suppression..." : "Supprimer la ligne"}
        destructive
        isLoading={Boolean(deletingLineId)}
        onCancel={handleCancelDeleteLine}
        onConfirm={handleConfirmDeleteLine}
      />

      <ConfirmModal
        open={isEmitConfirmOpen}
        title="Émettre définitivement cette facture ?"
        message="Une fois émise, cette facture sera numérotée et ne pourra plus être modifiée ni supprimée. Vérifiez les informations avant de continuer."
        cancelLabel="Annuler"
        confirmLabel={isEmitting ? "Émission en cours…" : "Émettre définitivement"}
        isLoading={isEmitting}
        onCancel={() => setIsEmitConfirmOpen(false)}
        onConfirm={() => {
          void handleConfirmEmitFacture();
        }}
      />

      <ConfirmModal
        open={Boolean(paiementToCancel)}
        title="Annuler ce paiement ?"
        message={
          paiementToCancel
            ? `Le paiement de ${formatCurrency(
                toNumber(paiementToCancel.montant),
              )} (${paiementToCancel.methode_libelle}) sera annulé. Le reste à payer sera recalculé.`
            : ""
        }
        cancelLabel="Annuler"
        confirmLabel={
          cancelingPaiementId ? "Annulation en cours…" : "Annuler le paiement"
        }
        destructive
        isLoading={Boolean(cancelingPaiementId)}
        onCancel={() => setPaiementToCancel(null)}
        onConfirm={() => {
          void handleConfirmCancelPaiement();
        }}
      />

      <ConfirmModal
        open={isTransmitConfirmOpen}
        title="Simuler une transmission de cette facture ?"
        message="Cette action simule un dépôt auprès d’une plateforme agréée factice (sandbox). Aucune vraie Plateforme Agréée n’est contactée. En cas de succès simulé, la facture passera au statut « déposée »."
        cancelLabel="Annuler"
        confirmLabel={
          isTransmitting
            ? "Simulation en cours…"
            : "Simuler une transmission (sandbox)"
        }
        isLoading={isTransmitting}
        onCancel={() => setIsTransmitConfirmOpen(false)}
        onConfirm={() => {
          void handleConfirmTransmit();
        }}
      />
    </section>
  );
}

function parseDecimal(value: string) {
  const parsed = Number(value.replace(",", "."));

  return Number.isFinite(parsed) ? parsed : 0;
}

function toNumber(value: string | number | null | undefined) {
  const parsed = Number(value ?? 0);

  return Number.isFinite(parsed) ? parsed : 0;
}

function formatCurrency(value: number) {
  const hasCents = Math.abs(value % 1) > 0;

  return new Intl.NumberFormat("fr-FR", {
    style: "currency",
    currency: "EUR",
    minimumFractionDigits: hasCents ? 2 : 0,
    maximumFractionDigits: hasCents ? 2 : 0,
  }).format(value);
}

function formatPercent(value: string | number | null | undefined) {
  return `${toNumber(value)} %`;
}

function formatQuantity(value: string | number | null | undefined) {
  return new Intl.NumberFormat("fr-FR", {
    maximumFractionDigits: 2,
  }).format(toNumber(value));
}

function formatDate(value: string | null | undefined) {
  if (!value) {
    return "Non renseignée";
  }

  return new Intl.DateTimeFormat("fr-FR", {
    day: "2-digit",
    month: "long",
    year: "numeric",
  }).format(new Date(value));
}

function formatFactureFormat(format: Facture["format"] | null | undefined) {
  const labels = {
    factur_x: "Factur-X",
    ubl: "UBL",
    cii: "CII",
  };

  if (!format) {
    return "Format inconnu";
  }

  return labels[format] ?? format;
}

function getConformiteErrors(result: ConformiteResult) {
  return result.erreurs ?? [];
}

function getConformiteWarnings(result: ConformiteResult) {
  return result.avertissements ?? result.warnings ?? [];
}