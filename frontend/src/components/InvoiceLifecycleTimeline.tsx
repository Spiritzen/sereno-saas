import {
  Archive,
  Ban,
  Check,
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
import { useStickyCompact } from "../hooks/useStickyCompact";
import type { FactureStatut } from "../types/facture";

type InvoiceLifecycleTimelineProps = {
  status: FactureStatut;
  createdAt?: string | null;
  emittedAt?: string | null;
  invoiceNumber?: string | null;
};

const MAIN_LIFECYCLE = [
  "brouillon",
  "emise",
  "deposee",
  "recue",
  "mise_a_disposition",
  "approuvee",
  "encaissee",
] as const;

type MainStatut = (typeof MAIN_LIFECYCLE)[number];

type StepMeta = {
  label: string;
  icon: LucideIcon;
  context: string;
  next?: string;
};

const STEP_META: Record<MainStatut, StepMeta> = {
  brouillon: {
    label: "Brouillon",
    icon: FileEdit,
    context:
      "La facture est en préparation. Vérifiez sa conformité avant de l’émettre.",
    next: "Émission",
  },
  emise: {
    label: "Émise",
    icon: Send,
    context:
      "La facture est émise et figée. Elle est prête pour la suite de son parcours.",
    next: "Dépôt",
  },
  deposee: {
    label: "Déposée",
    icon: UploadCloud,
    context: "La facture a été déposée et attend sa prise en charge.",
    next: "Réception",
  },
  recue: {
    label: "Reçue",
    icon: Inbox,
    context: "La facture a été reçue et poursuit son traitement.",
    next: "Mise à disposition",
  },
  mise_a_disposition: {
    label: "Mise à disposition",
    icon: Eye,
    context: "La facture est mise à disposition de son destinataire.",
    next: "Approbation",
  },
  approuvee: {
    label: "Approuvée",
    icon: CircleCheckBig,
    context: "La facture est approuvée et attend son règlement.",
    next: "Paiement",
  },
  encaissee: {
    label: "Paiement reçu",
    icon: CircleDollarSign,
    context: "Le paiement a été reçu. Le cycle principal est terminé.",
  },
};

type ExceptionStatut = "refusee" | "en_litige" | "annulee" | "archivee";

type ExceptionMeta = {
  label: string;
  icon: LucideIcon;
  title: string;
  context: string;
  variant: "danger" | "warning" | "neutral";
};

const EXCEPTION_META: Record<ExceptionStatut, ExceptionMeta> = {
  refusee: {
    label: "Refusée",
    icon: CircleX,
    title: "Facture refusée",
    context: "Une action de suivi est nécessaire.",
    variant: "danger",
  },
  en_litige: {
    label: "En litige",
    icon: Scale,
    title: "Facture en litige",
    context: "Son traitement nécessite une attention particulière.",
    variant: "warning",
  },
  annulee: {
    label: "Annulée",
    icon: Ban,
    title: "Facture annulée",
    context: "Le cycle de cette facture a été interrompu.",
    variant: "danger",
  },
  archivee: {
    label: "Archivée",
    icon: Archive,
    title: "Facture archivée",
    context: "Cette facture reste disponible en consultation.",
    variant: "neutral",
  },
};

function isMainStatut(status: FactureStatut): status is MainStatut {
  return (MAIN_LIFECYCLE as readonly string[]).includes(status);
}

function isExceptionStatut(status: FactureStatut): status is ExceptionStatut {
  return status in EXCEPTION_META;
}

function formatDateTime(value: string | null | undefined) {
  if (!value) {
    return null;
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return null;
  }

  const datePart = new Intl.DateTimeFormat("fr-FR", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  }).format(date);

  const timePart = new Intl.DateTimeFormat("fr-FR", {
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);

  return `${datePart} à ${timePart}`;
}

type StepVisualState = "completed" | "current" | "upcoming";

function resolveStepVisualState(
  stepIndex: number,
  currentMainIndex: number,
  isException: boolean,
): StepVisualState {
  if (isException) {
    return "upcoming";
  }

  if (stepIndex < currentMainIndex) {
    return "completed";
  }

  if (stepIndex === currentMainIndex) {
    return "current";
  }

  return "upcoming";
}

export function InvoiceLifecycleTimeline({
  status,
  createdAt,
  emittedAt,
  invoiceNumber,
}: InvoiceLifecycleTimelineProps) {
  const isException = isExceptionStatut(status);
  const currentMainIndex = isMainStatut(status)
    ? MAIN_LIFECYCLE.indexOf(status)
    : -1;

  const statusLabel = isMainStatut(status)
    ? STEP_META[status].label
    : isException
      ? EXCEPTION_META[status].label
      : status;

  const { sentinelRef, sectionRef, isEligibleForSticky, isCompact, spacerHeight } =
    useStickyCompact();

  return (
    <>
      <div ref={sentinelRef} aria-hidden="true" />

      <section
        ref={sectionRef}
        className={`invoice-lifecycle${
          isEligibleForSticky ? " invoice-lifecycle--sticky" : ""
        }${isCompact ? " invoice-lifecycle--compact" : ""}`}
        aria-label="Cycle de vie de la facture"
      >
        <div className="invoice-lifecycle__header">
          <div className="invoice-lifecycle__intro">
            <h2 className="invoice-lifecycle__title">
              Cycle de vie de la facture
            </h2>
            <p className="invoice-lifecycle__subtitle">
              Suivez son avancée, de la création au paiement.
            </p>
          </div>

          <span className="invoice-lifecycle__status status info">
            {statusLabel}
          </span>
        </div>

        <ol
          className={`invoice-lifecycle__track${
            isException ? " invoice-lifecycle__track--muted" : ""
          }`}
        >
          {MAIN_LIFECYCLE.map((step, index) => {
            const meta = STEP_META[step];
            const StepIcon = meta.icon;
            const visualState = resolveStepVisualState(
              index,
              currentMainIndex,
              isException,
            );
            const isCurrent = visualState === "current";

            let stepDate: string | null = null;

            if (step === "brouillon") {
              stepDate = formatDateTime(createdAt);
            }

            if (step === "emise") {
              stepDate = formatDateTime(emittedAt);
            }

            const showNumero = step === "emise" && Boolean(invoiceNumber);

            return (
              <li
                key={step}
                className={`invoice-lifecycle__step invoice-lifecycle__step--${visualState}`}
                aria-current={isCurrent ? "step" : undefined}
              >
                <span
                  className="invoice-lifecycle__connector"
                  aria-hidden="true"
                />

                <span className="invoice-lifecycle__marker" aria-hidden="true">
                  {visualState === "completed" ? (
                    <Check size={14} />
                  ) : (
                    <StepIcon size={14} />
                  )}
                </span>

                <span className="invoice-lifecycle__label">
                  {meta.label}
                  {isCurrent && (
                    <span className="invoice-lifecycle__current-tag">
                      Étape actuelle
                    </span>
                  )}
                  {visualState === "upcoming" && !isException && (
                    <span className="invoice-lifecycle__upcoming-tag">
                      À venir
                    </span>
                  )}
                </span>

                {(stepDate || showNumero) && (
                  <span className="invoice-lifecycle__meta">
                    {showNumero && <span>{invoiceNumber}</span>}
                    {stepDate && <span>{stepDate}</span>}
                  </span>
                )}
              </li>
            );
          })}
        </ol>

        {!isException && isMainStatut(status) && (
          <div className="invoice-lifecycle__context">
            <p>{STEP_META[status].context}</p>
            {STEP_META[status].next && (
              <p className="invoice-lifecycle__next">
                Prochaine étape : {STEP_META[status].next}
              </p>
            )}
          </div>
        )}

        {isExceptionStatut(status) && <ExceptionCard status={status} />}
      </section>

      {spacerHeight > 0 && (
        <div style={{ height: spacerHeight }} aria-hidden="true" />
      )}
    </>
  );
}

function ExceptionCard({ status }: { status: ExceptionStatut }) {
  const meta = EXCEPTION_META[status];
  const ExceptionIcon = meta.icon;

  return (
    <div
      className={`invoice-lifecycle__exception invoice-lifecycle__exception--${meta.variant}`}
    >
      <span className="invoice-lifecycle__exception-icon" aria-hidden="true">
        <ExceptionIcon size={22} />
      </span>

      <div>
        <strong>{meta.title}</strong>
        <p>{meta.context}</p>
      </div>
    </div>
  );
}
