import { BellRing } from "lucide-react";
import { useRelance } from "../hooks/useRelance";
import type { Facture } from "../types/facture";

function formatDate(value: string | null | undefined) {
  if (!value) {
    return null;
  }

  return new Intl.DateTimeFormat("fr-FR", {
    day: "2-digit",
    month: "long",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
}

type InvoiceRelanceSectionProps = {
  factureId: string;
  relancable: boolean;
  derniereRelanceAt: string | null | undefined;
  relancesCount: number | undefined;
  onFactureMutated: (facture: Facture) => void;
};

// Relances v1a — bouton manuel, visible UNIQUEMENT si le backend confirme
// `relancable` (aucune des 3 conditions d'éligibilité n'est recalculée ici,
// cf. Facture#relancable?). Reste discret si la facture n'a jamais été
// relancée : pas de section vide à afficher (contrairement aux paiements,
// toujours visibles dès qu'une facture est émise).
export function InvoiceRelanceSection({
  factureId,
  relancable,
  derniereRelanceAt,
  relancesCount,
  onFactureMutated,
}: InvoiceRelanceSectionProps) {
  const { isSending, relanceError, derniereRelance, handleRelancer } =
    useRelance(factureId, onFactureMutated);

  if (!relancable && !derniereRelanceAt) {
    return null;
  }

  const dateAffichee = formatDate(derniereRelance?.envoyee_at ?? derniereRelanceAt);

  return (
    <section
      className="invoice-transmission-section"
      aria-labelledby="facture-relance-title"
    >
      <div className="invoice-transmission-section__header">
        <div className="invoice-transmission-section__heading-row">
          <h2 id="facture-relance-title" className="invoice-transmission-section__title">
            Relance
          </h2>
        </div>
        <p className="invoice-transmission-section__subtitle">
          {dateAffichee
            ? `Dernière relance le ${dateAffichee}${
                relancesCount ? ` (${relancesCount} au total)` : ""
              }.`
            : "Aucune relance envoyée pour le moment."}
        </p>
      </div>

      {relancable && (
        <div className="invoice-actions-row">
          <button
            type="button"
            className="relance-btn"
            disabled={isSending}
            onClick={() => {
              void handleRelancer();
            }}
          >
            <BellRing size={16} />
            {isSending ? "Envoi en cours..." : "Relancer"}
          </button>
        </div>
      )}

      {derniereRelance && (
        <p className="relance-meta">
          {derniereRelance.statut === "envoyee"
            ? derniereRelance.mode_livraison === "letter_opener"
              ? "Relance envoyée — prévisu dev (letter_opener), non délivrée réellement."
              : "Relance envoyée."
            : "Échec de l'envoi — la relance est journalisée, réessayez plus tard."}
        </p>
      )}

      {relanceError && (
        <p className="invoice-transmission-section__error">{relanceError}</p>
      )}
    </section>
  );
}
