import { ExternalLink, Send } from "lucide-react";
import type { FactureStatut } from "../types/facture";

type StatusVariant = "success" | "info" | "warning" | "danger";

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

const STATUS_VARIANTS: Record<FactureStatut, StatusVariant> = {
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

const DUE_INACTIVE_STATUTS: ReadonlySet<FactureStatut> = new Set([
  "encaissee",
  "annulee",
  "archivee",
  "refusee",
  "en_litige",
]);

type DueState = "normal" | "soon" | "overdue";

type DueInfo = {
  state: DueState;
  label: string;
  detail: string;
};

function startOfDayTime(date: Date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
}

function formatDateLabel(value: string | null | undefined) {
  if (!value) {
    return null;
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return null;
  }

  return new Intl.DateTimeFormat("fr-FR", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  }).format(date);
}

function resolveDueInfo(
  dueDate: string | null | undefined,
  status: FactureStatut,
): DueInfo | null {
  if (!dueDate || DUE_INACTIVE_STATUTS.has(status)) {
    return null;
  }

  const parsed = new Date(dueDate);

  if (Number.isNaN(parsed.getTime())) {
    return null;
  }

  const formatted = formatDateLabel(dueDate);

  if (!formatted) {
    return null;
  }

  const diffDays = Math.round(
    (startOfDayTime(parsed) - startOfDayTime(new Date())) / 86_400_000,
  );

  if (diffDays < 0) {
    const daysLate = Math.abs(diffDays);
    return {
      state: "overdue",
      label: "En retard",
      detail: `Depuis ${daysLate} jour${daysLate > 1 ? "s" : ""}`,
    };
  }

  if (diffDays <= 7) {
    const dayLabel =
      diffDays === 0 ? "aujourd’hui" : `dans ${diffDays} jour${diffDays > 1 ? "s" : ""}`;

    return {
      state: "soon",
      label: "Échéance proche",
      detail: `${formatted} · ${dayLabel}`,
    };
  }

  return {
    state: "normal",
    label: "Échéance",
    detail: formatted,
  };
}

function formatMoney(value: number, currency: string) {
  return new Intl.NumberFormat("fr-FR", {
    style: "currency",
    currency: currency || "EUR",
  }).format(value);
}

type InvoiceDetailHeaderProps = {
  invoiceNumber: string | null;
  status: FactureStatut;
  clientName: string | null;
  clientMeta: string | null;
  totalHt: number;
  totalTva: number;
  totalTtc: number;
  currency: string;
  invoiceDate: string | null;
  emittedAt: string | null;
  dueDate: string | null;
  canEmit: boolean;
  isEmitting: boolean;
  hasPdf: boolean;
  hasXml: boolean;
  onEmit: () => void;
  onOpenPdf: () => void;
  onOpenXml: () => void;
};

export function InvoiceDetailHeader({
  invoiceNumber,
  status,
  clientName,
  clientMeta,
  totalHt,
  totalTva,
  totalTtc,
  currency,
  invoiceDate,
  emittedAt,
  dueDate,
  canEmit,
  isEmitting,
  hasPdf,
  hasXml,
  onEmit,
  onOpenPdf,
  onOpenXml,
}: InvoiceDetailHeaderProps) {
  const isDraft = status === "brouillon";
  const title = invoiceNumber ?? (isDraft ? "Facture en préparation" : "Facture");
  const dateLabel = formatDateLabel(isDraft ? invoiceDate : emittedAt);
  const dateCaption = isDraft ? "Créée le" : "Émise le";
  const dueInfo = resolveDueInfo(dueDate, status);
  const hasActions = canEmit || hasPdf || hasXml;

  return (
    <header className="invoice-detail-header">
      <div className="invoice-detail-header__identity">
        <span className="invoice-detail-header__eyebrow">Facture</span>
        <h2 className="invoice-detail-header__title">{title}</h2>
        {clientName && (
          <p className="invoice-detail-header__client">{clientName}</p>
        )}
        {clientMeta && (
          <p className="invoice-detail-header__client-meta">{clientMeta}</p>
        )}
      </div>

      <span
        className={`invoice-detail-header__status status ${STATUS_VARIANTS[status]}`}
      >
        {STATUS_LABELS[status]}
      </span>

      <div className="invoice-detail-header__value">
        <span className="invoice-detail-header__amount">
          {formatMoney(totalTtc, currency)}
        </span>
        <span className="invoice-detail-header__amount-label">Total TTC</span>
        <span className="invoice-detail-header__breakdown">
          HT {formatMoney(totalHt, currency)} · TVA {formatMoney(totalTva, currency)}
        </span>
      </div>

      <div className="invoice-detail-header__timing">
        {dateLabel && (
          <span className="invoice-detail-header__date">
            {dateCaption} {dateLabel}
          </span>
        )}

        {dueInfo && (
          <span
            className={`invoice-detail-header__due invoice-detail-header__due--${dueInfo.state}`}
          >
            <strong>{dueInfo.label}</strong>
            <span>{dueInfo.detail}</span>
          </span>
        )}
      </div>

      {hasActions && (
        <div className="invoice-detail-header__actions">
          {canEmit && (
            <button
              type="button"
              className="primary-btn invoice-detail-header__action"
              disabled={isEmitting}
              onClick={onEmit}
            >
              <Send size={16} aria-hidden="true" />
              {isEmitting ? "Émission..." : "Émettre"}
            </button>
          )}

          {hasPdf && (
            <button
              type="button"
              className="secondary-btn invoice-detail-header__action"
              onClick={onOpenPdf}
            >
              <ExternalLink size={16} aria-hidden="true" />
              Télécharger le PDF
            </button>
          )}

          {hasXml && (
            <button
              type="button"
              className="secondary-btn invoice-detail-header__action"
              onClick={onOpenXml}
            >
              <ExternalLink size={16} aria-hidden="true" />
              Télécharger le XML
            </button>
          )}
        </div>
      )}
    </header>
  );
}
