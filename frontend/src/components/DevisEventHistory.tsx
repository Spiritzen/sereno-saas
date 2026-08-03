import {
  CircleCheckBig,
  CircleX,
  FileText,
  Send,
  type LucideIcon,
} from "lucide-react";
import type {
  EvenementDevis,
  EvenementDevisAction,
} from "../types/evenementDevis";

// Fondation commune avec InvoiceEventHistory/CreditNoteEventHistory (mêmes
// classes CSS invoice-event-history__*), mais composant SÉPARÉ et non une
// fusion : contrairement à la facture/l'avoir, le devis journalise PAR
// ACTION (`details.action`), pas par `statut` seul — "devis_accepte" et
// "devis_converti" partagent le même statut ("accepte") mais des libellés et
// des payloads différents. Aucune création n'est journalisée côté backend
// (dette n°21 évitée à l'étage B) : jamais de "Devis créé" inventé ici.
const ACTION_LABELS: Record<EvenementDevisAction, string> = {
  devis_envoye: "Devis envoyé",
  devis_accepte: "Réponse enregistrée : accepté",
  devis_refuse: "Réponse enregistrée : refusé",
  devis_converti: "Converti en facture",
};

const ACTION_ICONS: Record<EvenementDevisAction, LucideIcon> = {
  devis_envoye: Send,
  devis_accepte: CircleCheckBig,
  devis_refuse: CircleX,
  devis_converti: FileText,
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

type DevisEventHistoryProps = {
  events: EvenementDevis[];
  isLoading: boolean;
  error: string | null;
};

export function DevisEventHistory({
  events,
  isLoading,
  error,
}: DevisEventHistoryProps) {
  return (
    <section
      className="invoice-event-history"
      aria-labelledby="devis-event-history-title"
    >
      <div className="invoice-event-history__header">
        <h2
          id="devis-event-history-title"
          className="invoice-event-history__title"
        >
          Historique du devis
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
          Aucun événement n’est encore disponible pour ce devis.
        </p>
      )}

      {!isLoading && !error && events.length > 0 && (
        <ol className="invoice-event-history__list">
          {events.map((event) => {
            const action = event.details.action;
            const label = action ? ACTION_LABELS[action] : "Événement";
            const EventIcon = action ? ACTION_ICONS[action] : FileText;
            const dateTimeLabel = formatEventDateTime(event.created_at);
            const factureNumero =
              action === "devis_converti"
                ? event.details.facture_numero
                : undefined;

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
                    {label}
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

                  {factureNumero && (
                    <span className="invoice-event-history__meta">
                      Facture {factureNumero}
                    </span>
                  )}
                </div>
              </li>
            );
          })}
        </ol>
      )}
    </section>
  );
}
