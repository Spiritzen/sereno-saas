import { CheckCircle2, Plus } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { listClients } from "../api/clientsApi";
import { listFactures } from "../api/facturesApi";
import type { Client } from "../types/client";
import type { Facture, FactureStatut } from "../types/facture";

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

const STATUS_VARIANTS: Record<FactureStatut, "success" | "info" | "warning" | "danger"> = {
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

export function DashboardPage() {
const [factures, setFactures] = useState<Facture[]>([]);
const [clientsById, setClientsById] = useState<Record<string, Client>>({});
const [isLoading, setIsLoading] = useState(true);
const [error, setError] = useState<string | null>(null);

useEffect(() => {
  Promise.all([listFactures(), listClients()])
    .then(([facturesData, clientsData]) => {
      const clientsMap = clientsData.reduce<Record<string, Client>>(
        (accumulator, client) => {
          accumulator[client.id] = client;
          return accumulator;
        },
        {},
      );

      setFactures(facturesData);
      setClientsById(clientsMap);
      setError(null);
    })
    .catch((apiError) => {
      setError(
        apiError instanceof Error
          ? apiError.message
          : "Impossible de charger le dashboard",
      );
    })
    .finally(() => {
      setIsLoading(false);
    });
}, []);

  const kpis = useMemo(() => buildDashboardKpis(factures), [factures]);

  const recentFactures = useMemo(
    () => factures.slice(0, 5),
    [factures],
  );

  return (
    <>
      <section className="hero-row">
        <div>
          <p className="eyebrow">{formatToday()}</p>
          <h1>Bonjour Sébastien</h1>
          <p className="eyebrow">Votre cockpit conformité est prêt.</p>
        </div>

        <Link to="/app/factures/new" className="primary-btn">
          <Plus size={16} /> Nouvelle facture conforme
        </Link>
      </section>

      <section className="compliance-banner">
        <div className="compliance-left">
          <div className="compliance-icon">
            <CheckCircle2 size={20} />
          </div>
          <div>
            <strong>Vous êtes conforme</strong>
            <p className="eyebrow">
              Réception électronique active · émission prête au format Factur-X
            </p>
          </div>
        </div>

        <div className="deadline">
          J-70
          <br />
          <small>1er sept. 2026</small>
        </div>
      </section>

      <section className="kpi-grid">
        <article className="kpi-card">
          <span>Encaissé · réel</span>
          <strong>{formatCurrency(kpis.encaisse)}</strong>
        </article>

        <article className="kpi-card">
          <span>En attente</span>
          <strong>{formatCurrency(kpis.enAttente)}</strong>
        </article>

        <article className="kpi-card danger">
          <span>En retard</span>
          <strong>{formatCurrency(kpis.enRetard)}</strong>
        </article>

        <article className="kpi-card success">
          <span>Conformité</span>
          <strong>{kpis.conformite}%</strong>
        </article>
      </section>

      <section>
        <div className="section-title">
          <h2>Factures récentes</h2>
          <span>Suivi du cycle de vie en temps réel</span>
        </div>

        {isLoading && (
          <div className="state-card">
            Chargement des factures...
          </div>
        )}

        {error && (
          <div className="state-card error">
            {error}
          </div>
        )}

        {!isLoading && !error && recentFactures.length === 0 && (
          <div className="state-card">
            Aucune facture pour le moment.
          </div>
        )}

        {!isLoading && !error && recentFactures.length > 0 && (
          <div className="invoice-list">
            {recentFactures.map((facture) => (
              <div className="invoice-row" key={facture.id}>
                <div>
                  <strong>{getClientName(facture, clientsById)}</strong>
                  <span className="invoice-meta">
                    {facture.numero ?? "Brouillon"} · {formatFactureFormat(facture.format)}
                  </span>
                </div>

                <div className="amount">
                  {formatCurrency(toNumber(facture.total_ttc))}
                </div>

                <div className={`status ${STATUS_VARIANTS[facture.statut]}`}>
                  {STATUS_LABELS[facture.statut]}
                </div>
              </div>
            ))}
          </div>
        )}
      </section>
    </>
  );
}

function buildDashboardKpis(factures: Facture[]) {
  const encaisse = factures
    .filter((facture) => facture.statut === "encaissee")
    .reduce((sum, facture) => sum + toNumber(facture.total_ttc), 0);

  const enAttente = factures
    .filter((facture) =>
      ["emise", "deposee", "recue", "mise_a_disposition", "approuvee"].includes(
        facture.statut,
      ),
    )
    .reduce((sum, facture) => sum + toNumber(facture.total_ttc), 0);

  const enRetard = factures
    .filter((facture) => isFactureEnRetard(facture))
    .reduce((sum, facture) => sum + toNumber(facture.total_ttc), 0);

  const facturesEmises = factures.filter((facture) => facture.statut !== "brouillon");

  const facturesAvecArchives = facturesEmises.filter(
    (facture) => facture.pdf_url && facture.xml_url,
  );

  const conformite =
    facturesEmises.length === 0
      ? 100
      : Math.round((facturesAvecArchives.length / facturesEmises.length) * 100);

  return {
    encaisse,
    enAttente,
    enRetard,
    conformite,
  };
}

function isFactureEnRetard(facture: Facture) {
  if (!facture.date_echeance) {
    return false;
  }

  if (["encaissee", "archivee", "annulee"].includes(facture.statut)) {
    return false;
  }

  const today = new Date();
  const dateEcheance = new Date(facture.date_echeance);

  return dateEcheance < today;
}

function getClientName(
  facture: Facture,
  clientsById: Record<string, Client>,
) {
  if (facture.client?.raison_sociale) {
    return facture.client.raison_sociale;
  }

  const client = clientsById[facture.client_id];

  if (client?.raison_sociale) {
    return client.raison_sociale;
  }

  return `Client ${facture.client_id.slice(0, 8)}`;
}

function formatFactureFormat(format: Facture["format"]) {
  const labels = {
    factur_x: "Factur-X",
    ubl: "UBL",
    cii: "CII",
  };

  return labels[format] ?? format;
}

function toNumber(value: string | number | null | undefined) {
  return Number(value ?? 0);
}

function formatCurrency(value: number) {
  return new Intl.NumberFormat("fr-FR", {
    style: "currency",
    currency: "EUR",
    maximumFractionDigits: 0,
  }).format(value);
}

function formatToday() {
  return new Intl.DateTimeFormat("fr-FR", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  }).format(new Date());
}