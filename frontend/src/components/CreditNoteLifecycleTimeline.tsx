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
import { useEffect, useRef, useState } from "react";
import type { AvoirStatut } from "../types/avoir";

// Duplication délibérée de InvoiceLifecycleTimeline (voie b, cohérente avec
// le style déjà établi côté backend — AvoirXmlService/FacturXXmlService,
// etc.) : même structure, même mécanique sticky/compact, mais un texte
// accordé au masculin ("l'avoir", jamais "la facture"). Un simple
// élargissement de type aurait laissé fuiter du texte grammaticalement faux
// ("la facture est émise" pour un avoir), pire qu'une duplication honnête.
type CreditNoteLifecycleTimelineProps = {
  status: AvoirStatut;
  createdAt?: string | null;
  emittedAt?: string | null;
  creditNoteNumber?: string | null;
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
    context: "L’avoir est en préparation. Ajoutez ou ajustez ses lignes avant de l’émettre.",
    next: "Émission",
  },
  emise: {
    label: "Émis",
    icon: Send,
    context: "L’avoir est émis et figé. Il est prêt pour la suite de son parcours.",
    next: "Dépôt",
  },
  deposee: {
    label: "Déposé",
    icon: UploadCloud,
    context: "L’avoir a été déposé et attend sa prise en charge.",
    next: "Réception",
  },
  recue: {
    label: "Reçu",
    icon: Inbox,
    context: "L’avoir a été reçu et poursuit son traitement.",
    next: "Mise à disposition",
  },
  mise_a_disposition: {
    label: "Mise à disposition",
    icon: Eye,
    context: "L’avoir est mis à disposition de son destinataire.",
    next: "Approbation",
  },
  approuvee: {
    label: "Approuvé",
    icon: CircleCheckBig,
    context: "L’avoir est approuvé.",
    next: "Clôture",
  },
  encaissee: {
    label: "Clôturé",
    icon: CircleDollarSign,
    context: "Le cycle principal de cet avoir est terminé.",
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
    label: "Refusé",
    icon: CircleX,
    title: "Avoir refusé",
    context: "Une action de suivi est nécessaire.",
    variant: "danger",
  },
  en_litige: {
    label: "En litige",
    icon: Scale,
    title: "Avoir en litige",
    context: "Son traitement nécessite une attention particulière.",
    variant: "warning",
  },
  annulee: {
    label: "Annulé",
    icon: Ban,
    title: "Avoir annulé",
    context: "Le cycle de cet avoir a été interrompu.",
    variant: "danger",
  },
  archivee: {
    label: "Archivé",
    icon: Archive,
    title: "Avoir archivé",
    context: "Cet avoir reste disponible en consultation.",
    variant: "neutral",
  },
};

function isMainStatut(status: AvoirStatut): status is MainStatut {
  return (MAIN_LIFECYCLE as readonly string[]).includes(status);
}

function isExceptionStatut(status: AvoirStatut): status is ExceptionStatut {
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

export function CreditNoteLifecycleTimeline({
  status,
  createdAt,
  emittedAt,
  creditNoteNumber,
}: CreditNoteLifecycleTimelineProps) {
  const isException = isExceptionStatut(status);
  const currentMainIndex = isMainStatut(status)
    ? MAIN_LIFECYCLE.indexOf(status)
    : -1;

  const statusLabel = isMainStatut(status)
    ? STEP_META[status].label
    : isException
      ? EXCEPTION_META[status].label
      : status;

  const sentinelRef = useRef<HTMLDivElement | null>(null);
  const sectionRef = useRef<HTMLElement | null>(null);
  const [isStuck, setIsStuck] = useState(false);
  const [isEligibleForSticky, setIsEligibleForSticky] = useState(false);

  useEffect(() => {
    function evaluerEligibilite() {
      const hauteurViewport = window.innerHeight;
      const hauteurDocument = document.documentElement.scrollHeight;

      setIsEligibleForSticky(hauteurDocument > hauteurViewport * 2);
    }

    evaluerEligibilite();

    const resizeObserver = new ResizeObserver(evaluerEligibilite);
    resizeObserver.observe(document.body);
    window.addEventListener("resize", evaluerEligibilite);

    return () => {
      resizeObserver.disconnect();
      window.removeEventListener("resize", evaluerEligibilite);
    };
  }, []);

  useEffect(() => {
    const sentinel = sentinelRef.current;

    if (!sentinel) {
      return;
    }

    const observer = new IntersectionObserver(
      ([entry]) => setIsStuck(isEligibleForSticky && !entry.isIntersecting),
      { threshold: 0, rootMargin: "-1px 0px 0px 0px" },
    );

    observer.observe(sentinel);

    return () => observer.disconnect();
  }, [isEligibleForSticky]);

  const isCompact = isEligibleForSticky && isStuck;

  const fullHeightRef = useRef(0);
  const [spacerHeight, setSpacerHeight] = useState(0);

  useEffect(() => {
    const section = sectionRef.current;

    if (!section) {
      return;
    }

    function mesurer() {
      const hauteurActuelle = section!.offsetHeight;

      if (!isCompact) {
        fullHeightRef.current = hauteurActuelle;
        setSpacerHeight(0);
        return;
      }

      setSpacerHeight(Math.max(0, fullHeightRef.current - hauteurActuelle));
    }

    mesurer();

    const resizeObserver = new ResizeObserver(mesurer);
    resizeObserver.observe(section);

    return () => resizeObserver.disconnect();
  }, [isCompact]);

  return (
    <>
      <div ref={sentinelRef} aria-hidden="true" />

      <section
        ref={sectionRef}
        className={`invoice-lifecycle${
          isEligibleForSticky ? " invoice-lifecycle--sticky" : ""
        }${isCompact ? " invoice-lifecycle--compact" : ""}`}
        aria-label="Cycle de vie de l’avoir"
      >
        <div className="invoice-lifecycle__header">
          <div className="invoice-lifecycle__intro">
            <h2 className="invoice-lifecycle__title">Cycle de vie de l’avoir</h2>
            <p className="invoice-lifecycle__subtitle">
              Suivez son avancée, de la création à la clôture.
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

            const showNumero = step === "emise" && Boolean(creditNoteNumber);

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
                    {showNumero && <span>{creditNoteNumber}</span>}
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
