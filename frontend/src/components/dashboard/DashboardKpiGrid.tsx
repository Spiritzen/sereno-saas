import { AlertTriangle, Clock3, FileCheck2, Wallet } from "lucide-react";
import { formatCurrency } from "../../lib/dashboardModel";
import type { DashboardKpis, DashboardStatus } from "../../lib/dashboardModel";

type DashboardKpiGridProps = {
  kpis: DashboardKpis;
  status: DashboardStatus;
};

// D1.1 §5 — un chargement en cours ou une erreur réseau ne sont jamais
// convertis implicitement en résultat métier : tant que `status !== "ready"`,
// aucune carte n'affiche de valeur numérique définitive (jamais "0 €" ni
// "100 %" pendant loading/error), seulement un texte neutre. La valeur/le
// libellé réel n'apparaît qu'à `status === "ready"` (data OU vide réel).
function renderMeta(status: DashboardStatus, readyMeta: string): string {
  if (status === "loading") return "Chargement…";
  if (status === "error") return "Données indisponibles";
  return readyMeta;
}

// D1 §3/§4.D — 4 cartes de poids visuel comparable, libellés honnêtes
// (jamais "Encaissé · réel" ni "Conformité" trompeurs, cf. §3 du prompt).
// Aucune sparkline/tendance/pourcentage de variation : rien de tout cela
// n'est une donnée d'historique réellement disponible aujourd'hui. Le vert
// n'apparaît QUE pour un accomplissement réel (complétude strictement à
// 100 % avec au moins une facture émise, ET status === "ready") ; le rouge
// QUE s'il existe réellement au moins une facture en retard à l'état ready.
export function DashboardKpiGrid({ kpis, status }: DashboardKpiGridProps) {
  const { encaissementConstate, enAttente, enRetard, completude } = kpis;
  const isReady = status === "ready";

  return (
    <section
      className="dashboard-kpi-grid"
      aria-label="Indicateurs de facturation"
      aria-busy={status === "loading" ? true : undefined}
    >
      <article className="dashboard-kpi-card">
        <div className="dashboard-kpi-card__header">
          <span className="dashboard-kpi-card__label">Encaissement constaté</span>
          <span className="dashboard-kpi-card__icon dashboard-kpi-card__icon--brand">
            <Wallet size={18} aria-hidden="true" />
          </span>
        </div>

        <strong className="dashboard-kpi-card__value">
          {isReady ? formatCurrency(encaissementConstate.total) : "—"}
        </strong>

        <p className="dashboard-kpi-card__meta">
          {renderMeta(
            status,
            `${encaissementConstate.count} facture${encaissementConstate.count > 1 ? "s" : ""} · statut réglementaire`,
          )}
        </p>
      </article>

      <article className="dashboard-kpi-card">
        <div className="dashboard-kpi-card__header">
          <span className="dashboard-kpi-card__label">En attente</span>
          <span className="dashboard-kpi-card__icon dashboard-kpi-card__icon--neutral">
            <Clock3 size={18} aria-hidden="true" />
          </span>
        </div>

        <strong className="dashboard-kpi-card__value">
          {isReady ? formatCurrency(enAttente.total) : "—"}
        </strong>

        <p className="dashboard-kpi-card__meta">
          {renderMeta(
            status,
            `TTC des factures en cours · ${enAttente.count} facture${enAttente.count > 1 ? "s" : ""}`,
          )}
        </p>
      </article>

      <article className="dashboard-kpi-card">
        <div className="dashboard-kpi-card__header">
          <span className="dashboard-kpi-card__label">En retard</span>
          <span className="dashboard-kpi-card__icon dashboard-kpi-card__icon--danger">
            <AlertTriangle size={18} aria-hidden="true" />
          </span>
        </div>

        <strong
          className={`dashboard-kpi-card__value${
            isReady && enRetard.count > 0 ? " dashboard-kpi-card__value--danger" : ""
          }`}
        >
          {isReady ? formatCurrency(enRetard.total) : "—"}
        </strong>

        <p className="dashboard-kpi-card__meta">
          {renderMeta(
            status,
            `TTC des factures échues · ${enRetard.count} facture${enRetard.count > 1 ? "s" : ""}`,
          )}
        </p>
      </article>

      <article className="dashboard-kpi-card">
        <div className="dashboard-kpi-card__header">
          <span className="dashboard-kpi-card__label">Complétude</span>
          <span
            className={`dashboard-kpi-card__icon ${
              isReady && completude.ratio === 100
                ? "dashboard-kpi-card__icon--success"
                : "dashboard-kpi-card__icon--neutral"
            }`}
          >
            <FileCheck2 size={18} aria-hidden="true" />
          </span>
        </div>

        <strong
          className={`dashboard-kpi-card__value${
            isReady && completude.ratio === 100 ? " dashboard-kpi-card__value--success" : ""
          }`}
        >
          {isReady ? (completude.ratio === null ? "—" : `${completude.ratio}%`) : "—"}
        </strong>

        <p className="dashboard-kpi-card__meta">
          {renderMeta(
            status,
            completude.emises === 0
              ? "Aucun document émis"
              : `PDF + XML disponibles · ${completude.completes}/${completude.emises}`,
          )}
        </p>
      </article>
    </section>
  );
}
