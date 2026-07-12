import {
  Archive,
  Ban,
  CircleCheckBig,
  CircleDollarSign,
  CircleX,
  Eye,
  FileEdit,
  Inbox,
  Scale,
  Send,
  UploadCloud,
  type LucideIcon,
} from "lucide-react";
import type {
  EvenementFacture,
  EvenementFactureSource,
} from "../types/evenementFacture";
import type { FactureStatut } from "../types/facture";

const STATUT_LABELS: Record<FactureStatut, string> = {
  brouillon: "Facture créée",
  emise: "Facture émise",
  deposee: "Facture déposée",
  recue: "Facture reçue",
  mise_a_disposition: "Facture mise à disposition",
  approuvee: "Facture approuvée",
  refusee: "Facture refusée",
  en_litige: "Facture placée en litige",
  encaissee: "Paiement reçu",
  archivee: "Facture archivée",
  annulee: "Facture annulée",
};

const STATUT_ICONS: Record<FactureStatut, LucideIcon> = {
  brouillon: FileEdit,
  emise: Send,
  deposee: UploadCloud,
  recue: Inbox,
  mise_a_disposition: Eye,
  approuvee: CircleCheckBig,
  refusee: CircleX,
  en_litige: Scale,
  encaissee: CircleDollarSign,
  archivee: Archive,
  annulee: Ban,
};

const SOURCE_LABELS: Record<EvenementFactureSource, string> = {
  interne: "Action interne",
  pa: "Plateforme agréée",
  webhook: "Notification externe",
  sandbox: "Simulation (sandbox)",
};

function formatEventDateTime(value: string) {
  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return null;
  }

  const datePart = new Intl.DateTimeFormat("fr-FR", {
    day: "numeric",
    month: "long",
    year: "numeric",
  }).format(date);

  const timePart = new Intl.DateTimeFormat("fr-FR", {
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);

  return `${datePart} à ${timePart}`;
}

type InvoiceEventHistoryProps = {
  events: EvenementFacture[];
  isLoading: boolean;
  error: string | null;
};

export function InvoiceEventHistory({
  events,
  isLoading,
  error,
}: InvoiceEventHistoryProps) {
  return (
    <section
      className="invoice-event-history"
      aria-labelledby="invoice-event-history-title"
    >
      <div className="invoice-event-history__header">
        <h2
          id="invoice-event-history-title"
          className="invoice-event-history__title"
        >
          Historique de la facture
        </h2>
        <p className="invoice-event-history__subtitle">
          Événements réellement enregistrés pour ce document.
        </p>
      </div>

      {isLoading && (
        <p className="invoice-event-history__loading">
          Chargement de l’historique...
        </p>
      )}

      {!isLoading && error && (
        <p className="invoice-event-history__error">{error}</p>
      )}

      {!isLoading && !error && events.length === 0 && (
        <p className="invoice-event-history__empty">
          Aucun événement n’est encore disponible pour cette facture.
        </p>
      )}

      {!isLoading && !error && events.length > 0 && (
        <ol className="invoice-event-history__list">
          {events.map((event) => {
            const EventIcon = STATUT_ICONS[event.statut];
            const dateTimeLabel = formatEventDateTime(event.created_at);
            const numero =
              event.statut === "emise" ? event.details.numero : undefined;

            return (
              <li key={event.id} className="invoice-event-history__item">
                <span
                  className="invoice-event-history__marker"
                  aria-hidden="true"
                >
                  <EventIcon size={16} />
                </span>

                <div className="invoice-event-history__content">
                  <span className="invoice-event-history__label">
                    {STATUT_LABELS[event.statut]}
                    {event.source === "sandbox" && (
                      <span className="invoice-event-history__simulation-badge">
                        Simulation
                      </span>
                    )}
                  </span>

                  {dateTimeLabel && (
                    <time
                      className="invoice-event-history__meta"
                      dateTime={event.created_at}
                    >
                      {dateTimeLabel}
                    </time>
                  )}

                  {event.actor && (
                    <span className="invoice-event-history__actor">
                      Par {event.actor.display_name}
                    </span>
                  )}

                  {numero && (
                    <span className="invoice-event-history__meta">
                      {numero}
                    </span>
                  )}

                  <span className="invoice-event-history__source">
                    {SOURCE_LABELS[event.source]}
                  </span>
                </div>
              </li>
            );
          })}
        </ol>
      )}
    </section>
  );
}
