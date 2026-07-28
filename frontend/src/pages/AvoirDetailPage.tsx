import { ArrowLeft, Receipt } from "lucide-react";
import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import {
  getAvoir,
  getAvoirPdfUrl,
  getAvoirXmlUrl,
} from "../api/avoirsApi";
import { listEvenementsAvoir } from "../api/evenementsAvoirApi";
import { getApiErrorMessage } from "../api/http";
import {
  getTransmissionFromError,
  listTransmissionsPaAvoir,
  simulerTransmissionPaAvoir,
  synchroniserTransmissionPaAvoir,
} from "../api/avoirTransmissionPaApi";
import { CreditNoteEventHistory } from "../components/CreditNoteEventHistory";
import { CreditNoteLifecycleTimeline } from "../components/CreditNoteLifecycleTimeline";
import { InvoiceDetailHeader } from "../components/InvoiceDetailHeader";
import { InvoiceTransmissionSection } from "../components/InvoiceTransmissionSection";
import { ConfirmModal } from "../components/ConfirmModal";
import type { Avoir } from "../types/avoir";
import type { EvenementAvoir } from "../types/evenementAvoir";
import type { PaSyncResult, TransmissionPa } from "../types/transmissionPa";

// Miroir de FactureDetailPage (V1.1), avec les mêmes composants réutilisés
// SANS modification (InvoiceDetailHeader, InvoiceTransmissionSection — tous
// deux déjà typés/pilotés uniquement par un statut/des montants génériques,
// AvoirStatut étant un alias strict de FactureStatut). Seuls le cycle de vie
// et l'historique sont dupliqués-adaptés (CreditNote*), pour un texte
// correctement accordé au masculin ("l'avoir").
const AVOIR_STATUTS_TERMINAUX = ["encaissee", "refusee", "annulee", "archivee"];

function resolveClientMeta(client: Avoir["client"]) {
  if (!client) {
    return null;
  }

  if (client.email) {
    return client.email;
  }

  if (client.ville && client.pays) {
    return `${client.ville}, ${client.pays}`;
  }

  return client.ville ?? null;
}

function toNumber(value: string | number | null | undefined) {
  const parsed = Number(value ?? 0);

  return Number.isFinite(parsed) ? parsed : 0;
}

export function AvoirDetailPage() {
  const { id } = useParams<{ id: string }>();

  const [avoir, setAvoir] = useState<Avoir | null>(null);
  const [isLoading, setIsLoading] = useState(Boolean(id));
  const [error, setError] = useState<string | null>(null);

  const [events, setEvents] = useState<EvenementAvoir[]>([]);
  const [isLoadingEvents, setIsLoadingEvents] = useState(Boolean(id));
  const [eventsError, setEventsError] = useState<string | null>(null);

  const [transmissions, setTransmissions] = useState<TransmissionPa[]>([]);
  const [isLoadingTransmissions, setIsLoadingTransmissions] = useState(Boolean(id));
  const [transmissionsError, setTransmissionsError] = useState<string | null>(null);
  const [isTransmitting, setIsTransmitting] = useState(false);
  const [isTransmitConfirmOpen, setIsTransmitConfirmOpen] = useState(false);

  const [isSynchronizing, setIsSynchronizing] = useState(false);
  const [syncResult, setSyncResult] = useState<PaSyncResult | null>(null);
  const [syncError, setSyncError] = useState<string | null>(null);

  const isDraft = avoir?.statut === "brouillon";
  const hasPdf = Boolean(avoir?.pdf_url);
  const hasXml = Boolean(avoir?.xml_url);

  const derniereTransmission = transmissions[0] ?? null;
  const canSynchronize =
    Boolean(avoir) &&
    derniereTransmission?.statut === "depose" &&
    !AVOIR_STATUTS_TERMINAUX.includes(avoir?.statut ?? "");

  useEffect(() => {
    if (!id) {
      return;
    }

    let ignore = false;

    void getAvoir(id)
      .then((data) => {
        if (!ignore) {
          setAvoir(data);
          setError(null);
        }
      })
      .catch((apiError) => {
        if (!ignore) {
          setError(getApiErrorMessage(apiError));
        }
      })
      .finally(() => {
        if (!ignore) {
          setIsLoading(false);
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

    void listEvenementsAvoir(id)
      .then((data) => {
        if (!ignore) {
          setEvents(data);
          setEventsError(null);
        }
      })
      .catch((apiError) => {
        if (!ignore) {
          setEventsError(getApiErrorMessage(apiError));
        }
      })
      .finally(() => {
        if (!ignore) {
          setIsLoadingEvents(false);
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

    void listTransmissionsPaAvoir(id)
      .then((data) => {
        if (!ignore) {
          setTransmissions(data);
          setTransmissionsError(null);
        }
      })
      .catch((apiError) => {
        if (!ignore) {
          setTransmissionsError(getApiErrorMessage(apiError));
        }
      })
      .finally(() => {
        if (!ignore) {
          setIsLoadingTransmissions(false);
        }
      });

    return () => {
      ignore = true;
    };
  }, [id]);

  function upsertTransmission(previous: TransmissionPa[], transmission: TransmissionPa) {
    const autres = previous.filter((item) => item.id !== transmission.id);
    return [transmission, ...autres];
  }

  async function handleSimulateTransmission() {
    if (!avoir) {
      return;
    }

    setIsTransmitting(true);

    try {
      const transmission = await simulerTransmissionPaAvoir(avoir.id);
      setTransmissions((previous) => upsertTransmission(previous, transmission));
    } catch (apiError) {
      const transmissionEnErreur = getTransmissionFromError(apiError);

      if (transmissionEnErreur) {
        setTransmissions((previous) => upsertTransmission(previous, transmissionEnErreur));
      } else {
        setTransmissionsError(getApiErrorMessage(apiError));
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
    if (!avoir) {
      return;
    }

    setSyncError(null);
    setIsSynchronizing(true);

    try {
      const result = await synchroniserTransmissionPaAvoir(avoir.id);

      setSyncResult(result);
      setTransmissions((previous) => upsertTransmission(previous, result.transmission));

      if (result.resultat === "applied") {
        const [updatedAvoir, updatedEvents] = await Promise.all([
          getAvoir(avoir.id),
          listEvenementsAvoir(avoir.id),
        ]);

        setAvoir(updatedAvoir);
        setEvents(updatedEvents);
      }
    } catch (apiError) {
      setSyncResult(null);
      setSyncError(getApiErrorMessage(apiError));
    } finally {
      setIsSynchronizing(false);
    }
  }

  function handleOpenPdf() {
    if (!avoir || !hasPdf) {
      return;
    }

    window.open(getAvoirPdfUrl(avoir.id), "_blank", "noopener,noreferrer");
  }

  function handleOpenXml() {
    if (!avoir || !hasXml) {
      return;
    }

    window.open(getAvoirXmlUrl(avoir.id), "_blank", "noopener,noreferrer");
  }

  return (
    <section className="new-invoice-page">
      <div className="page-heading">
        <div>
          <span className="page-kicker">Détail avoir</span>
          <h1>Détail de l’avoir</h1>
          <p>Consultez le document, son historique et sa transmission.</p>
        </div>

        <Link to="/app/factures" className="secondary-btn">
          <ArrowLeft size={16} />
          Retour factures
        </Link>
      </div>

      {isLoading && <div className="state-card">Chargement de l’avoir...</div>}

      {error && <div className="state-card error">{error}</div>}

      {!isLoading && !avoir && !error && (
        <div className="state-card">Avoir introuvable.</div>
      )}

      {!isLoading && avoir && (
        <div className="avoir-identity-strip">
          <span className="badge-avoir">
            <Receipt size={14} /> Avoir
          </span>

          {avoir.facture_numero && (
            <Link
              to={`/app/factures/${avoir.facture_id}`}
              className="avoir-accent-text"
            >
              Avoir sur facture {avoir.facture_numero}
            </Link>
          )}

          <span>Motif : {avoir.motif}</span>
        </div>
      )}

      {!isLoading && avoir && (
        <InvoiceDetailHeader
          invoiceNumber={avoir.numero}
          status={avoir.statut}
          clientName={avoir.client?.raison_sociale ?? null}
          clientMeta={resolveClientMeta(avoir.client)}
          totalHt={toNumber(avoir.total_ht)}
          totalTva={toNumber(avoir.total_tva)}
          totalTtc={toNumber(avoir.total_ttc)}
          currency="EUR"
          invoiceDate={avoir.created_at ?? null}
          emittedAt={avoir.emis_at}
          dueDate={null}
          hasPdf={hasPdf}
          hasXml={hasXml}
          onOpenPdf={handleOpenPdf}
          onOpenXml={handleOpenXml}
        />
      )}

      {!isLoading && avoir && isDraft && (
        <div className="state-card">
          Cet avoir est encore un brouillon. Reprenez sa création depuis la
          facture d’origine pour ajuster ses lignes et l’émettre.
        </div>
      )}

      {!isLoading && avoir && (
        <CreditNoteLifecycleTimeline
          status={avoir.statut}
          createdAt={avoir.created_at}
          emittedAt={avoir.emis_at}
          creditNoteNumber={avoir.numero}
        />
      )}

      {!isLoading && avoir && (
        <CreditNoteEventHistory
          events={events}
          isLoading={isLoadingEvents}
          error={eventsError}
        />
      )}

      {!isLoading &&
        avoir &&
        (avoir.statut !== "brouillon" || transmissions.length > 0) && (
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
            requiresReviewCount={null}
            isRelaunching={false}
            relaunchError={null}
            onRelaunch={() => {}}
          />
        )}

      <ConfirmModal
        open={isTransmitConfirmOpen}
        title="Simuler une transmission de cet avoir ?"
        message="Cette action simule un dépôt auprès d’une plateforme agréée factice (sandbox). Aucune vraie Plateforme Agréée n’est contactée."
        cancelLabel="Annuler"
        confirmLabel={isTransmitting ? "Simulation en cours…" : "Simuler une transmission (sandbox)"}
        isLoading={isTransmitting}
        onCancel={() => setIsTransmitConfirmOpen(false)}
        onConfirm={() => {
          void handleConfirmTransmit();
        }}
      />
    </section>
  );
}
