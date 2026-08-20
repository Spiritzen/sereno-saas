import { Calendar } from "lucide-react";
import { Link } from "react-router-dom";
import {
  buildCalendarMonth,
  buildEcheancesAVenir,
  formatCurrency,
  formatEcheanceLabel,
  getClientName,
  getFactureTotalTtc,
} from "../../lib/dashboardModel";
import type { DashboardStatus } from "../../lib/dashboardModel";
import type { Client } from "../../types/client";
import type { Facture } from "../../types/facture";
import { SectionHeading } from "../SectionHeading";

const DEADLINES_LIMIT = 3;

function formatDayAriaLabel(jour: {
  date: Date;
  isToday: boolean;
  hasEcheance: boolean;
  hasEcheanceEnRetard: boolean;
}): string {
  const label = new Intl.DateTimeFormat("fr-FR", {
    weekday: "long",
    day: "numeric",
    month: "long",
  }).format(jour.date);

  const suffixes: string[] = [];
  if (jour.isToday) suffixes.push("aujourd'hui");
  if (jour.hasEcheanceEnRetard) suffixes.push("échéance en retard");
  else if (jour.hasEcheance) suffixes.push("échéance");

  return suffixes.length > 0 ? `${label}, ${suffixes.join(", ")}` : label;
}

type DeadlinesPanelProps = {
  factures: Facture[];
  clientsById: Record<string, Client>;
  today: Date;
  status: DashboardStatus;
};

// D1.1 §5 — le calendrier reste affiché pendant loading/error (sa grille de
// dates et le jour "aujourd'hui" ne dépendent d'aucune donnée réseau), mais
// ne porte jamais de pastille d'échéance tant que `status !== "ready"` (on
// ne SAIT pas encore, on n'affirme donc rien). La liste des échéances sous
// le calendrier, elle, ne prétend "Aucune échéance à suivre" que lorsque la
// réponse a réellement réussi et est réellement vide.
export function DeadlinesPanel({ factures, clientsById, today, status }: DeadlinesPanelProps) {
  const facturesConnues = status === "ready" ? factures : [];
  const calendrier = buildCalendarMonth(facturesConnues, today);
  const echeances = buildEcheancesAVenir(facturesConnues, DEADLINES_LIMIT, today);

  return (
    <section
      className="dashboard-panel"
      aria-label="Échéances réelles"
      aria-busy={status === "loading" ? true : undefined}
    >
      <SectionHeading
        icon={<Calendar size={18} aria-hidden="true" />}
        title="Échéances à venir"
        action={
          <Link to="/app/factures" className="section-action-link">
            Voir tout →
          </Link>
        }
      />

      <div className="dashboard-calendar">
        <p className="dashboard-calendar__label">{calendrier.label}</p>

        <div className="dashboard-calendar__grid" role="img" aria-label={`Calendrier de ${calendrier.label}`}>
          {calendrier.weekdays.map((jour, index) => (
            <span className="dashboard-calendar__weekday" key={`weekday-${index}`} aria-hidden="true">
              {jour}
            </span>
          ))}

          {calendrier.weeks.flat().map((jour) => {
            const classNames = ["dashboard-calendar__day"];
            if (!jour.isCurrentMonth) classNames.push("dashboard-calendar__day--muted");
            if (jour.isToday) classNames.push("dashboard-calendar__day--today");

            return (
              <span
                className={classNames.join(" ")}
                key={jour.date.toISOString()}
                aria-hidden="true"
                title={formatDayAriaLabel(jour)}
              >
                {jour.date.getDate()}
                {jour.hasEcheance && (
                  <span
                    className={`dashboard-calendar__day-marker${
                      jour.hasEcheanceEnRetard ? " dashboard-calendar__day-marker--danger" : ""
                    }`}
                  />
                )}
              </span>
            );
          })}
        </div>
      </div>

      {status === "loading" && <div className="state-card">Chargement des échéances…</div>}

      {status === "error" && <div className="state-card error">Données indisponibles</div>}

      {status === "ready" && echeances.length === 0 && (
        <div className="state-card">Aucune échéance à suivre pour le moment.</div>
      )}

      {status === "ready" && echeances.length > 0 && (
        <ul className="dashboard-deadline-list">
          {echeances.map(({ facture, enRetard }) => (
            <li key={facture.id}>
              <Link to={`/app/factures/${facture.id}`} className="dashboard-deadline-item">
                <span
                  className={`dashboard-deadline-item__dot${
                    enRetard ? " dashboard-deadline-item__dot--danger" : ""
                  }`}
                  aria-hidden="true"
                />

                <span className="dashboard-deadline-item__client">
                  <strong>{getClientName(facture, clientsById)}</strong>
                  <span>{facture.numero ?? "Brouillon"}</span>
                </span>

                <span className="dashboard-deadline-item__amount">
                  <strong>{formatCurrency(getFactureTotalTtc(facture))}</strong>
                  <span>{enRetard ? "En retard" : formatEcheanceLabel(facture.date_echeance)}</span>
                </span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
