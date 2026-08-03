import { Wallet } from "lucide-react";
import { usePaiements } from "../hooks/usePaiements";
import { ConfirmModal } from "./ConfirmModal";
import { MOYENS_PAIEMENT, type Paiement, type PaiementMethodeCode } from "../types/paiement";

const PAIEMENT_STATUT_LABELS: Record<Paiement["statut"], string> = {
  brouillon: "Brouillon",
  confirme: "Confirmé",
  annule: "Annulé",
};

function toNumber(value: string | number | null | undefined) {
  const parsed = Number(value ?? 0);

  return Number.isFinite(parsed) ? parsed : 0;
}

function formatCurrency(value: number) {
  const hasCents = Math.abs(value % 1) > 0;

  return new Intl.NumberFormat("fr-FR", {
    style: "currency",
    currency: "EUR",
    minimumFractionDigits: hasCents ? 2 : 0,
    maximumFractionDigits: hasCents ? 2 : 0,
  }).format(value);
}

function formatDate(value: string | null | undefined) {
  if (!value) {
    return "Non renseignée";
  }

  return new Intl.DateTimeFormat("fr-FR", {
    day: "2-digit",
    month: "long",
    year: "numeric",
  }).format(new Date(value));
}

type InvoicePaymentsSectionProps = {
  factureId: string;
  montantPaye: number;
  resteDu: number;
  resteAPayer: number;
  onFactureMutated: () => void | Promise<void>;
};

// Extrait de FactureDetailPage (étage C) : bloc paiement complet (liste,
// historique par paiement, formulaire d'enregistrement). Comportement
// STRICTEMENT identique à l'original — voir usePaiements pour l'état/les
// appels API. Rendu uniquement pour une facture non-brouillon (déjà garanti
// par l'appelant, comme avant l'extraction).
export function InvoicePaymentsSection({
  factureId,
  montantPaye,
  resteDu,
  resteAPayer,
  onFactureMutated,
}: InvoicePaymentsSectionProps) {
  const {
    paiements,
    isLoadingPaiements,
    paiementsError,
    montantPaiement,
    setMontantPaiement,
    methodePaiement,
    setMethodePaiement,
    datePaiement,
    setDatePaiement,
    referencePaiement,
    setReferencePaiement,
    isRegisteringPaiement,
    paiementError,
    confirmingPaiementId,
    cancelingPaiementId,
    paiementToCancel,
    expandedPaiementId,
    paiementEvents,
    loadingPaiementEventsId,
    handleRegisterPaiement,
    handleConfirmPaiement,
    handleAskCancelPaiement,
    handleCancelCancelPaiement,
    handleConfirmCancelPaiement,
    handleToggleHistoriquePaiement,
  } = usePaiements(factureId, onFactureMutated);

  return (
    <>
      <section
        className="invoice-transmission-section"
        aria-labelledby="facture-paiements-title"
      >
        <div className="invoice-transmission-section__header">
          <div className="invoice-transmission-section__heading-row">
            <h2
              id="facture-paiements-title"
              className="invoice-transmission-section__title"
            >
              Paiements
            </h2>
          </div>
          <p className="invoice-transmission-section__subtitle">
            {formatCurrency(montantPaye)} encaissés sur{" "}
            {formatCurrency(resteDu)} dus après avoirs — reste{" "}
            {formatCurrency(resteAPayer)} à payer.
          </p>
        </div>

        {isLoadingPaiements && (
          <p className="invoice-transmission-section__loading">
            Chargement des paiements...
          </p>
        )}

        {!isLoadingPaiements && paiementsError && (
          <p className="invoice-transmission-section__error">
            {paiementsError}
          </p>
        )}

        {!isLoadingPaiements && !paiementsError && paiements.length === 0 && (
          <p className="invoice-transmission-section__empty">
            Aucun paiement n’a encore été enregistré pour cette facture.
          </p>
        )}

        {!isLoadingPaiements && paiements.length > 0 && (
          <div className="invoice-lines-table">
            <div className="invoice-lines-header">
              <span>Date</span>
              <span>Moyen</span>
              <span>Référence</span>
              <span>Montant</span>
              <span>Statut</span>
            </div>

            {paiements.map((paiement) => (
              <div key={paiement.id}>
                <div
                  className={`invoice-lines-row ${
                    paiement.statut === "annule" ? "paiement-row--annule" : ""
                  }`}
                >
                  <span>{formatDate(paiement.date_encaissement)}</span>
                  <span>{paiement.methode_libelle}</span>
                  <span>{paiement.reference || "—"}</span>
                  <strong>{formatCurrency(toNumber(paiement.montant))}</strong>
                  <span
                    className={`badge-paiement ${
                      paiement.statut === "annule"
                        ? "badge-paiement--annule"
                        : ""
                    }`}
                  >
                    {PAIEMENT_STATUT_LABELS[paiement.statut]}
                  </span>
                </div>

                <div className="invoice-actions-row">
                  <button
                    type="button"
                    className="table-action-btn"
                    onClick={() => {
                      void handleToggleHistoriquePaiement(paiement);
                    }}
                  >
                    {expandedPaiementId === paiement.id
                      ? "Masquer l’historique"
                      : "Historique"}
                  </button>

                  {paiement.statut === "brouillon" && (
                    <button
                      type="button"
                      className="paiement-btn"
                      disabled={confirmingPaiementId === paiement.id}
                      onClick={() => {
                        void handleConfirmPaiement(paiement);
                      }}
                    >
                      {confirmingPaiementId === paiement.id
                        ? "Confirmation..."
                        : "Confirmer"}
                    </button>
                  )}

                  {paiement.statut === "confirme" && (
                    <button
                      type="button"
                      className="table-action-btn danger"
                      disabled={cancelingPaiementId === paiement.id}
                      onClick={() => handleAskCancelPaiement(paiement)}
                    >
                      {cancelingPaiementId === paiement.id
                        ? "Annulation..."
                        : "Annuler"}
                    </button>
                  )}
                </div>

                {expandedPaiementId === paiement.id && (
                  <div className="state-card">
                    {loadingPaiementEventsId === paiement.id
                      ? "Chargement de l’historique..."
                      : (paiementEvents[paiement.id]?.length ?? 0) > 0
                        ? (
                          <ul>
                            {paiementEvents[paiement.id].map((evenement) => (
                              <li key={evenement.id}>
                                {formatDate(evenement.created_at)} —{" "}
                                {PAIEMENT_STATUT_LABELS[evenement.statut]}
                                {evenement.actor
                                  ? ` (${evenement.actor.display_name})`
                                  : ""}
                              </li>
                            ))}
                          </ul>
                        )
                        : "Aucun événement."}
                  </div>
                )}
              </div>
            ))}
          </div>
        )}

        <form className="line-form" onSubmit={handleRegisterPaiement}>
          <div className="line-form-grid">
            <label>
              Montant
              <input
                type="number"
                step="0.01"
                min="0.01"
                value={montantPaiement}
                placeholder="500"
                onChange={(event) => setMontantPaiement(event.target.value)}
              />
            </label>

            <label>
              Moyen
              <select
                value={methodePaiement}
                onChange={(event) =>
                  setMethodePaiement(
                    event.target.value as PaiementMethodeCode,
                  )
                }
              >
                {MOYENS_PAIEMENT.map((moyen) => (
                  <option key={moyen.code} value={moyen.code}>
                    {moyen.libelle}
                  </option>
                ))}
              </select>
            </label>

            <label>
              Date d’encaissement
              <input
                type="date"
                value={datePaiement}
                onChange={(event) => setDatePaiement(event.target.value)}
              />
            </label>

            <label>
              Référence (optionnel)
              <input
                type="text"
                value={referencePaiement}
                placeholder="VIR-2026-001"
                onChange={(event) =>
                  setReferencePaiement(event.target.value)
                }
              />
            </label>
          </div>

          <div className="invoice-actions-row">
            <button
              type="submit"
              className="paiement-btn"
              disabled={isRegisteringPaiement}
            >
              <Wallet size={16} />
              {isRegisteringPaiement
                ? "Enregistrement..."
                : "Enregistrer un paiement"}
            </button>
          </div>
        </form>

        {paiementError && (
          <p className="invoice-transmission-section__error">
            {paiementError}
          </p>
        )}
      </section>

      <ConfirmModal
        open={Boolean(paiementToCancel)}
        title="Annuler ce paiement ?"
        message={
          paiementToCancel
            ? `Le paiement de ${formatCurrency(
                toNumber(paiementToCancel.montant),
              )} (${paiementToCancel.methode_libelle}) sera annulé. Le reste à payer sera recalculé.`
            : ""
        }
        cancelLabel="Annuler"
        confirmLabel={
          cancelingPaiementId ? "Annulation en cours…" : "Annuler le paiement"
        }
        destructive
        isLoading={Boolean(cancelingPaiementId)}
        onCancel={handleCancelCancelPaiement}
        onConfirm={() => {
          void handleConfirmCancelPaiement();
        }}
      />
    </>
  );
}
