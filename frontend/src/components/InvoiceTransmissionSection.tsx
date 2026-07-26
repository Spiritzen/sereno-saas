import { PlayCircle, RadioTower, RefreshCw, TriangleAlert } from "lucide-react";
import type {
  PaSyncResult,
  TransmissionPa,
  TransmissionPaStatut,
} from "../types/transmissionPa";
import type { FactureStatut } from "../types/facture";

const STATUT_LABELS: Record<TransmissionPaStatut, string> = {
  en_attente: "En attente",
  depose: "Déposée",
  accepte: "Acceptée",
  rejete: "Rejetée",
  erreur: "Échec technique",
};

const FACTURE_STATUT_LABELS: Record<FactureStatut, string> = {
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

type InvoiceTransmissionSectionProps = {
  transmissions: TransmissionPa[];
  isLoading: boolean;
  error: string | null;
  isTransmitting: boolean;
  onSimulate: () => void;
  canSynchronize: boolean;
  isSynchronizing: boolean;
  syncResult: PaSyncResult | null;
  syncError: string | null;
  onSynchronize: () => void;
  // V1.1-B3.2 — supervision.
  requiresReviewCount: number | null;
  isRelaunching: boolean;
  relaunchError: string | null;
  onRelaunch: () => void;
};

export function InvoiceTransmissionSection({
  transmissions,
  isLoading,
  error,
  isTransmitting,
  onSimulate,
  canSynchronize,
  isSynchronizing,
  syncResult,
  syncError,
  onSynchronize,
  requiresReviewCount,
  isRelaunching,
  relaunchError,
  onRelaunch,
}: InvoiceTransmissionSectionProps) {
  const derniereTransmission = transmissions[0] ?? null;
  const estEnErreur = derniereTransmission?.statut === "erreur";
  const estEnPause = derniereTransmission?.polling_paused === true;

  return (
    <section
      className="invoice-transmission-section"
      aria-labelledby="invoice-transmission-title"
    >
      <div className="invoice-transmission-section__header">
        <div className="invoice-transmission-section__heading-row">
          <h2
            id="invoice-transmission-title"
            className="invoice-transmission-section__title"
          >
            Transmission
          </h2>

          {Boolean(requiresReviewCount) && (
            <span
              className="invoice-transmission-review-badge"
              title="Nombre de transmissions dont la dernière notification reçue est une incohérence à examiner"
            >
              <TriangleAlert size={14} />
              {requiresReviewCount} à examiner
            </span>
          )}
        </div>
        <p className="invoice-transmission-section__subtitle">
          Simulez le dépôt de cette facture auprès d’une plateforme agréée
          (environnement sandbox — aucune vraie Plateforme Agréée n’est
          contactée).
        </p>
      </div>

      {isLoading && (
        <p className="invoice-transmission-section__loading">
          Chargement de l’état de transmission...
        </p>
      )}

      {!isLoading && error && (
        <p className="invoice-transmission-section__error">{error}</p>
      )}

      {!isLoading && !error && derniereTransmission && (
        <div
          className={`invoice-transmission-status invoice-transmission-status--${derniereTransmission.statut}`}
        >
          <div className="invoice-transmission-status__row">
            <span className="invoice-transmission-status__label">
              {STATUT_LABELS[derniereTransmission.statut]}
            </span>

            {derniereTransmission.simulation && (
              <span className="invoice-transmission-badge">Simulation</span>
            )}
          </div>

          <dl className="invoice-transmission-status__details">
            <div>
              <dt>Fournisseur</dt>
              <dd>{derniereTransmission.fournisseur}</dd>
            </div>

            {derniereTransmission.external_id && (
              <div>
                <dt>Identifiant externe</dt>
                <dd>{derniereTransmission.external_id}</dd>
              </div>
            )}

            {derniereTransmission.tentative > 1 && (
              <div>
                <dt>Tentatives</dt>
                <dd>{derniereTransmission.tentative}</dd>
              </div>
            )}

            {derniereTransmission.last_polled_at && (
              <div>
                <dt>Dernière synchronisation</dt>
                <dd>{formatDelaiRelatif(derniereTransmission.last_polled_at, { past: true })}</dd>
              </div>
            )}

            {derniereTransmission.consecutive_poll_errors > 0 && (
              <div>
                <dt>Erreurs consécutives</dt>
                <dd>{derniereTransmission.consecutive_poll_errors}</dd>
              </div>
            )}
          </dl>

          {estEnErreur && derniereTransmission.message_erreur && (
            <p className="invoice-transmission-status__message">
              {derniereTransmission.message_erreur}
            </p>
          )}
        </div>
      )}

      {!isLoading && !error && !derniereTransmission && (
        <p className="invoice-transmission-section__empty">
          Cette facture n’a pas encore été transmise.
        </p>
      )}

      {syncResult && (
        <SyncResultBanner result={syncResult} />
      )}

      {!isSynchronizing && syncError && (
        <p className="invoice-transmission-section__error">{syncError}</p>
      )}

      {!isRelaunching && relaunchError && (
        <p className="invoice-transmission-section__error">{relaunchError}</p>
      )}

      {canSynchronize && derniereTransmission && (
        <PollingStatusNote transmission={derniereTransmission} />
      )}

      <div className="invoice-transmission-section__actions">
        <button
          type="button"
          className="secondary-btn"
          disabled={isTransmitting}
          onClick={onSimulate}
        >
          <RadioTower size={16} />
          {isTransmitting
            ? "Simulation en cours..."
            : estEnErreur
              ? "Réessayer"
              : "Simuler une transmission (sandbox)"}
        </button>

        {canSynchronize && (
          <button
            type="button"
            className="secondary-btn"
            disabled={isSynchronizing}
            onClick={onSynchronize}
          >
            <RefreshCw size={16} />
            {isSynchronizing ? "Vérification en cours..." : "Vérifier maintenant"}
          </button>
        )}

        {estEnPause && (
          <button
            type="button"
            className="secondary-btn"
            disabled={isRelaunching}
            onClick={onRelaunch}
          >
            <PlayCircle size={16} />
            {isRelaunching ? "Relance en cours..." : "Relancer la synchronisation"}
          </button>
        )}
      </div>
    </section>
  );
}

function SyncResultBanner({ result }: { result: PaSyncResult }) {
  switch (result.resultat) {
    case "applied":
      return (
        <p className="invoice-transmission-section__sync-result invoice-transmission-section__sync-result--success">
          Nouveau statut : {FACTURE_STATUT_LABELS[result.statut_facture_apres] ?? result.statut_facture_apres}
        </p>
      );
    case "duplicate":
    case "stale":
      return (
        <p className="invoice-transmission-section__sync-result invoice-transmission-section__sync-result--neutral">
          Aucun changement depuis la dernière vérification.
        </p>
      );
    case "unmapped":
      return (
        <p className="invoice-transmission-section__sync-result invoice-transmission-section__sync-result--neutral">
          Statut fournisseur non reconnu.
        </p>
      );
    case "requires_review":
      return (
        <p className="invoice-transmission-section__sync-result invoice-transmission-section__sync-result--warning">
          <TriangleAlert size={16} />
          Incohérence à examiner{result.motif ? ` — ${result.motif}` : ""}
        </p>
      );
    default:
      return null;
  }
}

const POLLING_STOP_REASON_LABELS: Record<string, string> = {
  facture_terminale: "la facture a atteint un statut définitif",
  polling_expired: "le délai maximal de vérification est dépassé",
  plateforme_desactivee: "la plateforme agréée est déconnectée",
  transmission_cloturee: "la transmission est clôturée",
};

// Le strict nécessaire pour que l'utilisateur comprenne qu'il n'a rien à
// faire (vérification automatique en cours) ou pourquoi elle ne tourne
// plus. Pas de bouton de relance après pause : B3.2.
function PollingStatusNote({ transmission }: { transmission: TransmissionPa }) {
  if (transmission.polling_stopped) {
    const raison = transmission.polling_stop_reason
      ? (POLLING_STOP_REASON_LABELS[transmission.polling_stop_reason] ??
        transmission.polling_stop_reason)
      : null;

    return (
      <p className="invoice-transmission-section__polling-note">
        Vérification automatique arrêtée{raison ? ` — ${raison}` : ""}.
      </p>
    );
  }

  if (transmission.polling_paused) {
    return (
      <p className="invoice-transmission-section__polling-note">
        Vérification automatique en pause (erreurs techniques répétées). Vous
        pouvez continuer à vérifier manuellement.
      </p>
    );
  }

  if (transmission.next_poll_at) {
    return (
      <p className="invoice-transmission-section__polling-note">
        Prochaine vérification automatique : {formatDelaiRelatif(transmission.next_poll_at)}.
      </p>
    );
  }

  return null;
}

function formatDelaiRelatif(iso: string, options?: { past?: boolean }) {
  const past = options?.past ?? false;
  const cible = new Date(iso).getTime();

  if (Number.isNaN(cible)) {
    return "bientôt";
  }

  const diffMs = past ? Date.now() - cible : cible - Date.now();

  if (diffMs <= 0) {
    return past ? "à l’instant" : "dans un instant";
  }

  const diffMinutes = Math.round(diffMs / 60_000);

  if (diffMinutes < 1) {
    return past ? "il y a moins d’une minute" : "dans moins d’une minute";
  }

  if (diffMinutes < 60) {
    return past
      ? `il y a ${diffMinutes} minute${diffMinutes > 1 ? "s" : ""}`
      : `dans ${diffMinutes} minute${diffMinutes > 1 ? "s" : ""}`;
  }

  const diffHeures = Math.round(diffMinutes / 60);

  if (diffHeures < 24) {
    return past
      ? `il y a ${diffHeures} heure${diffHeures > 1 ? "s" : ""}`
      : `dans ${diffHeures} heure${diffHeures > 1 ? "s" : ""}`;
  }

  const diffJours = Math.round(diffHeures / 24);

  return past
    ? `il y a ${diffJours} jour${diffJours > 1 ? "s" : ""}`
    : `dans ${diffJours} jour${diffJours > 1 ? "s" : ""}`;
}
