import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import {
  getFacturePortail,
  getFacturePortailPdfUrl,
  listAvoirsPortail,
} from "../api/portailApi";
import { getApiErrorMessage } from "../api/http";
import { InvoiceDetailHeader } from "../components/InvoiceDetailHeader";
import type { PortailAvoir, PortailFacture } from "../types/portail";

function resolvePortailClientMeta(client: PortailFacture["client"]) {
  if (!client) {
    return null;
  }

  if (client.ville && client.pays) {
    return `${client.ville}, ${client.pays}`;
  }

  if (client.ville) {
    return client.ville;
  }

  if (client.siret) {
    return `SIRET ${client.siret}`;
  }

  return null;
}

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
  non_payee: "Non payée",
  partielle: "Partielle",
  soldee: "Soldée",
};

// Portail destinataire (MVP) — page PUBLIQUE, autonome, hors ProtectedRoute
// (App.tsx) : AUCUNE session, AUCUN appel authentifié, AUCUN lien vers le
// reste de l'app (c'est une page pour un TIERS, pas pour un utilisateur
// Sereno — cf. §5 execution_portail_destinataire_mvp.txt). Un token
// inconnu/expiré/révoqué produit exactement le même message d'erreur —
// jamais de distinction exploitable (même discipline que le backend).
export function PortalPage() {
  const { token } = useParams<{ token: string }>();

  const [facture, setFacture] = useState<PortailFacture | null>(null);
  const [avoirs, setAvoirs] = useState<PortailAvoir[]>([]);
  const [isLoading, setIsLoading] = useState(Boolean(token));
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!token) {
      return;
    }

    let ignore = false;

    void Promise.all([getFacturePortail(token), listAvoirsPortail(token)])
      .then(([factureData, avoirsData]) => {
        if (ignore) {
          return;
        }

        setFacture(factureData);
        setAvoirs(avoirsData);
        setError(null);
      })
      .catch((apiError) => {
        if (ignore) {
          return;
        }

        setError(getApiErrorMessage(apiError));
      })
      .finally(() => {
        if (!ignore) {
          setIsLoading(false);
        }
      });

    return () => {
      ignore = true;
    };
  }, [token]);

  function handleOpenPdf() {
    if (!token || !facture?.pdf_disponible) {
      return;
    }

    window.open(getFacturePortailPdfUrl(token), "_blank", "noopener,noreferrer");
  }

  return (
    <main className="portal-page">
      <section className="new-invoice-page">
        <div className="login-brand" style={{ marginBottom: 24 }}>
          <div className="brand-mark">S</div>
          <div>
            <strong>Sereno</strong>
            <span>Consultation de facture</span>
          </div>
        </div>

        {isLoading && (
          <div className="state-card">Chargement de la facture...</div>
        )}

        {!isLoading && !token && (
          <div className="state-card error">
            Ce lien n'est plus valide. Contactez l'émetteur de la facture pour
            en obtenir un nouveau.
          </div>
        )}

        {!isLoading && token && error && (
          <div className="state-card error">
            {error === "Lien invalide ou expiré"
              ? "Ce lien n'est plus valide. Contactez l'émetteur de la facture pour en obtenir un nouveau."
              : error}
          </div>
        )}

        {!isLoading && !error && facture && (
          <>
            <InvoiceDetailHeader
              invoiceNumber={facture.numero}
              status={facture.statut}
              clientName={facture.client?.raison_sociale ?? null}
              clientMeta={resolvePortailClientMeta(facture.client)}
              totalHt={toNumber(facture.total_ht)}
              totalTva={toNumber(facture.total_tva)}
              totalTtc={toNumber(facture.total_ttc)}
              currency={facture.devise}
              invoiceDate={facture.date_emission}
              emittedAt={facture.emise_at}
              dueDate={facture.date_echeance}
              hasPdf={facture.pdf_disponible}
              hasXml={false}
              onOpenPdf={handleOpenPdf}
              onOpenXml={() => {}}
            />

            <div className="invoice-builder-card">
              <div className="invoice-totals-card">
                <div>
                  <span>Total TTC</span>
                  <strong>
                    {formatCurrency(toNumber(facture.total_ttc), facture.devise)}
                  </strong>
                </div>

                <div className="total-ttc-row">
                  <span>
                    Reste à payer
                    <span className="badge-paiement" style={{ marginLeft: 8 }}>
                      {STATUT_ENCAISSEMENT_LABELS[facture.statut_encaissement_local] ??
                        facture.statut_encaissement_local}
                    </span>
                  </span>
                  <strong>
                    {formatCurrency(toNumber(facture.reste_a_payer), facture.devise)}
                  </strong>
                </div>
              </div>
            </div>

            {facture.lignes_facture.length > 0 && (
              <div className="invoice-builder-card">
                <div className="invoice-lines-table">
                  <div className="invoice-lines-header">
                    <span>Désignation</span>
                    <span>Qté</span>
                    <span>PU HT</span>
                    <span>TVA</span>
                    <span>Total TTC</span>
                  </div>

                  {facture.lignes_facture.map((ligne) => (
                    <div className="invoice-lines-row" key={ligne.id}>
                      <strong>{ligne.designation}</strong>
                      <span>{toNumber(ligne.quantite)}</span>
                      <span>{formatCurrency(toNumber(ligne.prix_unitaire_ht), facture.devise)}</span>
                      <span>{toNumber(ligne.taux_tva)} %</span>
                      <strong>{formatCurrency(toNumber(ligne.total_ttc), facture.devise)}</strong>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {avoirs.length > 0 && (
              <div className="invoice-builder-card">
                <h2 style={{ marginTop: 0 }}>Avoirs</h2>

                <div className="invoice-lines-table">
                  <div className="invoice-lines-header">
                    <span>Numéro</span>
                    <span>Motif</span>
                    <span>Statut</span>
                    <span>Montant TTC</span>
                  </div>

                  {avoirs.map((avoir) => (
                    <div className="invoice-lines-row" key={avoir.id}>
                      <strong>{avoir.numero ?? "—"}</strong>
                      <span>{avoir.motif}</span>
                      <span>{avoir.statut}</span>
                      <strong>{formatCurrency(toNumber(avoir.total_ttc), facture.devise)}</strong>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </>
        )}
      </section>
    </main>
  );
}
