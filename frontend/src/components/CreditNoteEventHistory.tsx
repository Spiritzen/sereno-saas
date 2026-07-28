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
  EvenementAvoir,
  EvenementAvoirSource,
} from "../types/evenementAvoir";
import type { AvoirStatut } from "../types/avoir";

// Duplication délibérée de InvoiceEventHistory (mêmes classes CSS
// invoice-event-history__*, réutilisées telles quelles) : seul le texte est
// accordé au masculin ("avoir", jamais "facture").
const STATUT_LABELS: Record<AvoirStatut, string> = {
  brouillon: "Avoir créé",
  emise: "Avoir émis",
  deposee: "Avoir déposé",
  recue: "Avoir reçu",
  mise_a_disposition: "Avoir mis à disposition",
  approuvee: "Avoir approuvé",
  refusee: "Avoir refusé",
  en_litige: "Avoir placé en litige",
  encaissee: "Avoir clôturé",
  archivee: "Avoir archivé",
  annulee: "Avoir annulé",
};

const STATUT_ICONS: Record<AvoirStatut, LucideIcon> = {
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

const SOURCE_LABELS: Record<EvenementAvoirSource, string> = {
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

type CreditNoteEventHistoryProps = {
  events: EvenementAvoir[];
  isLoading: boolean;
  error: string | null;
};

export function CreditNoteEventHistory({
  events,
  isLoading,
  error,
}: CreditNoteEventHistoryProps) {
  return (
    <section
      className="invoice-event-history"
      aria-labelledby="credit-note-event-history-title"
    >
      <div className="invoice-event-history__header">
        <h2
          id="credit-note-event-history-title"
          className="invoice-event-history__title"
        >
          Historique de l’avoir
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
          Aucun événement n’est encore disponible pour cet avoir.
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
