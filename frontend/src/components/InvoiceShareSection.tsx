import { Ban, Check, Copy, Share2 } from "lucide-react";
import { useState } from "react";
import { usePortailLien } from "../hooks/usePortailLien";

type InvoiceShareSectionProps = {
  factureId: string;
};

// Portail destinataire (MVP) — bouton owner "Générer le lien de partage" /
// "Révoquer le lien". Le token BRUT n'existe qu'UNE fois, dans la réponse
// de génération : cette section l'affiche une seule fois avec une action
// copier, jamais un endpoint pour le "retrouver" plus tard (il n'existe
// structurellement pas côté backend — cf. PortailFactureToken).
export function InvoiceShareSection({ factureId }: InvoiceShareSectionProps) {
  const { isGenerating, isRevoking, lienUrl, error, handleGenerer, handleRevoquer } =
    usePortailLien(factureId);
  const [isCopied, setIsCopied] = useState(false);

  async function handleCopy() {
    if (!lienUrl) {
      return;
    }

    try {
      await navigator.clipboard.writeText(lienUrl);
      setIsCopied(true);
      setTimeout(() => setIsCopied(false), 2000);
    } catch {
      // Sobre : le lien reste affiché et sélectionnable manuellement même
      // si l'API Clipboard échoue (contexte non sécurisé, permission refusée).
    }
  }

  async function handleRevoquerEtEffacer() {
    await handleRevoquer();
    setIsCopied(false);
  }

  return (
    <section
      className="invoice-transmission-section"
      aria-labelledby="facture-partage-title"
    >
      <div className="invoice-transmission-section__header">
        <div className="invoice-transmission-section__heading-row">
          <h2 id="facture-partage-title" className="invoice-transmission-section__title">
            Partage
          </h2>
        </div>
        <p className="invoice-transmission-section__subtitle">
          Un lien public, en lecture seule, pour que votre client consulte
          cette facture et télécharge le PDF — sans compte à créer.
        </p>
      </div>

      {!lienUrl && (
        <div className="invoice-actions-row">
          <button
            type="button"
            className="secondary-btn"
            disabled={isGenerating}
            onClick={() => {
              void handleGenerer();
            }}
          >
            <Share2 size={16} />
            {isGenerating ? "Génération..." : "Générer le lien de partage"}
          </button>
        </div>
      )}

      {lienUrl && (
        <>
          <div className="relance-meta">
            <code style={{ userSelect: "all", wordBreak: "break-all" }}>
              {lienUrl}
            </code>
          </div>

          <div className="invoice-actions-row">
            <button type="button" className="secondary-btn" onClick={() => void handleCopy()}>
              {isCopied ? <Check size={16} /> : <Copy size={16} />}
              {isCopied ? "Copié !" : "Copier le lien"}
            </button>

            <button
              type="button"
              className="table-action-btn danger"
              disabled={isRevoking}
              onClick={() => {
                void handleRevoquerEtEffacer();
              }}
            >
              <Ban size={16} />
              {isRevoking ? "Révocation..." : "Révoquer le lien"}
            </button>
          </div>
        </>
      )}

      {error && <p className="invoice-transmission-section__error">{error}</p>}
    </section>
  );
}
