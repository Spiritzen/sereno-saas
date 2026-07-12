import { RadioTower } from "lucide-react";
import type {
  TransmissionPa,
  TransmissionPaStatut,
} from "../types/transmissionPa";

const STATUT_LABELS: Record<TransmissionPaStatut, string> = {
  en_attente: "En attente",
  depose: "Déposée",
  accepte: "Acceptée",
  rejete: "Rejetée",
  erreur: "Échec technique",
};

type InvoiceTransmissionSectionProps = {
  transmissions: TransmissionPa[];
  isLoading: boolean;
  error: string | null;
  isTransmitting: boolean;
  onSimulate: () => void;
};

export function InvoiceTransmissionSection({
  transmissions,
  isLoading,
  error,
  isTransmitting,
  onSimulate,
}: InvoiceTransmissionSectionProps) {
  const derniereTransmission = transmissions[0] ?? null;
  const estEnErreur = derniereTransmission?.statut === "erreur";

  return (
    <section
      className="invoice-transmission-section"
      aria-labelledby="invoice-transmission-title"
    >
      <div className="invoice-transmission-section__header">
        <h2
          id="invoice-transmission-title"
          className="invoice-transmission-section__title"
        >
          Transmission
        </h2>
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
      </div>
    </section>
  );
}
