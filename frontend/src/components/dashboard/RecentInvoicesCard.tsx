import { ChevronRight, FileText } from "lucide-react";
import { Link } from "react-router-dom";
import {
  formatCurrency,
  formatFactureFormat,
  getClientName,
  getFactureTotalTtc,
} from "../../lib/dashboardModel";
import type { DashboardStatus } from "../../lib/dashboardModel";
import type { Client } from "../../types/client";
import type { Facture, FactureStatut } from "../../types/facture";
import { SectionHeading } from "../SectionHeading";

const STATUS_LABELS: Record<FactureStatut, string> = {
  brouillon: "Brouillon",
  emise: "Émise",
  deposee: "Déposée",
  recue: "Reçue",
  mise_a_disposition: "Mise à disposition",
  approuvee: "Approuvée",
  refusee: "Refusée",
  en_litige: "En litige",
  encaissee: "Paiement reçu",
  archivee: "Archivée",
  annulee: "Annulée",
};

const STATUS_VARIANTS: Record<FactureStatut, "success" | "info" | "warning" | "danger"> = {
  brouillon: "warning",
  emise: "warning",
  deposee: "info",
  recue: "info",
  mise_a_disposition: "info",
  approuvee: "info",
  refusee: "danger",
  en_litige: "danger",
  encaissee: "success",
  archivee: "info",
  annulee: "danger",
};

function formatInvoiceDate(facture: Facture): string {
  const value = facture.emise_at ?? facture.created_at;
  if (!value) return "—";
  return new Intl.DateTimeFormat("fr-FR", { day: "2-digit", month: "short" }).format(
    new Date(value),
  );
}

type RecentInvoicesCardProps = {
  factures: Facture[];
  clientsById: Record<string, Client>;
  status: DashboardStatus;
  errorMessage: string | null;
};

// D1.1 §5 — carte primaire, désignée porteuse UNIQUE du message d'erreur
// réel (role="alert") : les autres panneaux dérivés des factures
// (DashboardKpiGrid, DeadlinesPanel, AttentionPanel) affichent un texte
// neutre "Données indisponibles" plutôt que de répéter la même alerte
// quatre fois. `factures` n'est lu que si `status === "ready"` — jamais
// pendant loading/error, même s'il s'agit techniquement d'un tableau vide.
export function RecentInvoicesCard({
  factures,
  clientsById,
  status,
  errorMessage,
}: RecentInvoicesCardProps) {
  return (
    <section className="dashboard-invoices-card" aria-busy={status === "loading" ? true : undefined}>
      <SectionHeading
        icon={<FileText size={18} aria-hidden="true" />}
        title="Factures récentes"
        subtitle="Suivi du cycle de vie en temps réel"
        action={
          <Link to="/app/factures" className="section-action-link">
            Voir toutes les factures →
          </Link>
        }
      />

      {status === "loading" && <div className="state-card">Chargement des factures...</div>}

      {status === "error" && (
        <div className="state-card error" role="alert">
          {errorMessage ?? "Données indisponibles"}
        </div>
      )}

      {status === "ready" && factures.length === 0 && (
        <div className="state-card">Aucune facture pour le moment.</div>
      )}

      {status === "ready" && factures.length > 0 && (
        <div className="dashboard-invoices-list">
          {factures.map((facture) => (
            <Link
              to={`/app/factures/${facture.id}`}
              className="dashboard-invoice-row"
              key={facture.id}
            >
              <span className="dashboard-invoice-row__client">
                <span className="document-icon" aria-hidden="true">
                  <FileText size={16} />
                </span>

                <span>
                  <strong>{getClientName(facture, clientsById)}</strong>
                  <span>
                    {facture.numero ?? "Brouillon"} · {formatFactureFormat(facture.format)}
                  </span>
                </span>
              </span>

              <span className="dashboard-invoice-row__date">{formatInvoiceDate(facture)}</span>

              <span className="dashboard-invoice-row__amount">
                {formatCurrency(getFactureTotalTtc(facture))}
              </span>

              <span className="dashboard-invoice-row__end">
                <span className={`status ${STATUS_VARIANTS[facture.statut]}`}>
                  {STATUS_LABELS[facture.statut]}
                </span>
                <ChevronRight size={16} className="dashboard-invoice-row__chevron" aria-hidden="true" />
              </span>
            </Link>
          ))}
        </div>
      )}
    </section>
  );
}
