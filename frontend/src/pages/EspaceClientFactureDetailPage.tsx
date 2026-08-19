import { ArrowLeft } from "lucide-react";
import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { getFacture, getFacturePdfUrl } from "../api/destinataireApi";
import { estErreurNonAuthentifie } from "../api/destinataireHttp";
import { getApiErrorMessage } from "../api/http";
import { InvoiceDetailHeader } from "../components/InvoiceDetailHeader";
import type { EspaceClientFactureDetail } from "../types/espaceClient";

function toNumber(value: string | number | null | undefined) {
  const parsed = Number(value ?? 0);

  return Number.isFinite(parsed) ? parsed : 0;
}

function formatCurrency(value: number, currency: string) {
  return new Intl.NumberFormat("fr-FR", {
    style: "currency",
    currency: currency || "EUR",
  }).format(value);
}

const STATUT_ENCAISSEMENT_LABELS: Record<string, string> = {
  non_payee: "En attente",
  partielle: "Partielle",
  soldee: "Payée",
};

// §1 execution_espace_client_sidebar_pagination_badge.txt — même règle que
// EspaceClientFacturesPage : "en attente" (non_payee/partielle) en AMBRE,
// "payée" (soldee) reste au teal par défaut de .badge-paiement.
function classeBadgePaiement(statut: string) {
  return statut === "soldee" ? "badge-paiement" : "badge-paiement badge-paiement--attente";
}

// Route authentifiée /espace-client/factures/:id (C2) — JUMEAU structurel de
// PortalPage.tsx (même DA, même réutilisation d'InvoiceDetailHeader/
// invoice-lines-table) mais authentifié via destinataireApi, avec fil
// d'Ariane vers la liste. Un 404 (facture hors périmètre — isolation gérée
// par le backend, jamais recalculée ici) affiche un état sobre + retour liste.
export function EspaceClientFactureDetailPage() {
  const { id } = useParams<{ id: string }>();

  const [detail, setDetail] = useState<EspaceClientFactureDetail | null>(null);
  const [isLoading, setIsLoading] = useState(Boolean(id));
  const [notFound, setNotFound] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!id) {
      return;
    }

    let ignore = false;

    void getFacture(id)
      .then((data) => {
        if (ignore) {
          return;
        }

        setDetail(data);
        setError(null);
        setNotFound(false);
      })
      .catch((apiError) => {
        if (ignore) {
          return;
        }

        // fix_espace_client_auth_deconnexion — un 401 n'est jamais une
        // erreur de DONNÉES : le contexte (invalidé par l'intercepteur, cf.
        // destinataireHttp.ts) et ProtectedDestinataireRoute redirigent déjà
        // vers la connexion, jamais un message brut affiché ici.
        if (estErreurNonAuthentifie(apiError)) {
          return;
        }

        if (
          typeof apiError === "object" &&
          apiError !== null &&
          "response" in apiError &&
          (apiError as { response?: { status?: number } }).response?.status === 404
        ) {
          setNotFound(true);
        } else {
          setError(getApiErrorMessage(apiError));
        }
      })
      .finally(() => {
        if (!ignore) {
          setIsLoading(false);
        }
      });

    return () => {
      ignore = true;
    };
  }, [id]);

  function handleOpenPdf() {
    if (!id || !detail?.facture.pdf_disponible) {
      return;
    }

    window.open(getFacturePdfUrl(id), "_blank", "noopener,noreferrer");
  }

  return (
    <section className="new-invoice-page">
      <div className="page-heading">
        <div>
          <span className="page-kicker">Espace client</span>
          <h1>Détail de la facture</h1>
        </div>

        <Link to="/espace-client" className="secondary-btn">
          <ArrowLeft size={16} />
          Retour à mes factures
        </Link>
      </div>

      {isLoading && <div className="state-card">Chargement de la facture...</div>}

      {!isLoading && notFound && (
        <div className="state-card error">
          Facture introuvable.
          <div className="invoice-actions-row" style={{ marginTop: 12 }}>
            <Link to="/espace-client" className="secondary-btn">
              Retour à mes factures
            </Link>
          </div>
        </div>
      )}

      {!isLoading && !notFound && error && <div className="state-card error">{error}</div>}

      {!isLoading && !notFound && !error && detail && (
        <>
          <InvoiceDetailHeader
            invoiceNumber={detail.facture.numero}
            status={detail.facture.statut}
            clientName={detail.fournisseur.raison_sociale}
            clientMeta={null}
            totalHt={toNumber(detail.facture.total_ht)}
            totalTva={toNumber(detail.facture.total_tva)}
            totalTtc={toNumber(detail.facture.total_ttc)}
            currency={detail.facture.devise}
            invoiceDate={detail.facture.date_emission}
            emittedAt={detail.facture.emise_at}
            dueDate={detail.facture.date_echeance}
            hasPdf={detail.facture.pdf_disponible}
            hasXml={false}
            onOpenPdf={handleOpenPdf}
            onOpenXml={() => {}}
          />

          <div className="invoice-builder-card">
            <div className="invoice-totals-card">
              <div>
                <span>Total TTC</span>
                <strong>{formatCurrency(toNumber(detail.facture.total_ttc), detail.facture.devise)}</strong>
              </div>

              <div className="total-ttc-row">
                <span>
                  Reste à payer
                  <span
                    className={classeBadgePaiement(detail.facture.statut_encaissement_local)}
                    style={{ marginLeft: 8 }}
                  >
                    {STATUT_ENCAISSEMENT_LABELS[detail.facture.statut_encaissement_local] ??
                      detail.facture.statut_encaissement_local}
                  </span>
                </span>
                <strong>
                  {formatCurrency(toNumber(detail.facture.reste_a_payer), detail.facture.devise)}
                </strong>
              </div>
            </div>
          </div>

          {detail.facture.lignes_facture.length > 0 && (
            <div className="invoice-builder-card">
              <div className="invoice-lines-table">
                <div className="invoice-lines-header">
                  <span>Désignation</span>
                  <span>Qté</span>
                  <span>PU HT</span>
                  <span>TVA</span>
                  <span>Total TTC</span>
                </div>

                {detail.facture.lignes_facture.map((ligne) => (
                  <div className="invoice-lines-row" key={ligne.id}>
                    <strong>{ligne.designation}</strong>
                    <span>{toNumber(ligne.quantite)}</span>
                    <span>
                      {formatCurrency(toNumber(ligne.prix_unitaire_ht), detail.facture.devise)}
                    </span>
                    <span>{toNumber(ligne.taux_tva)} %</span>
                    <strong>{formatCurrency(toNumber(ligne.total_ttc), detail.facture.devise)}</strong>
                  </div>
                ))}
              </div>
            </div>
          )}

          {detail.avoirs.length > 0 && (
            <div className="invoice-builder-card">
              <h2 style={{ marginTop: 0 }}>Avoirs</h2>

              <div className="invoice-lines-table">
                <div className="invoice-lines-header">
                  <span>Numéro</span>
                  <span>Motif</span>
                  <span>Statut</span>
                  <span>Montant TTC</span>
                </div>

                {detail.avoirs.map((avoir) => (
                  <div className="invoice-lines-row" key={avoir.id}>
                    <strong>{avoir.numero ?? "—"}</strong>
                    <span>{avoir.motif}</span>
                    <span>{avoir.statut}</span>
                    <strong>{formatCurrency(toNumber(avoir.total_ttc), detail.facture.devise)}</strong>
                  </div>
                ))}
              </div>
            </div>
          )}
        </>
      )}
    </section>
  );
}
