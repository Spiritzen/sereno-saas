import { CheckCircle2, Plus } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { listClients } from "../api/clientsApi";
import { listFactures } from "../api/facturesApi";
import { SectionHeading } from "../components/SectionHeading";
import { useAuth } from "../context/useAuth";
import type { Client } from "../types/client";
import type { Facture, FactureStatut } from "../types/facture";

const RECENT_FACTURES_LIMIT = 5;
const ECHEANCES_LIMIT = 5;
const ECHEANCE_RECEPTION_ELECTRONIQUE = new Date("2026-09-01T00:00:00");

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

const STATUS_VARIANTS: Record<
  FactureStatut,
  "success" | "info" | "warning" | "danger"
> = {
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
  const { utilisateur } = useAuth();

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
    () => factures.slice(0, RECENT_FACTURES_LIMIT),
    [factures],
  );

  // Calendrier d'échéances — DÉRIVÉ des factures déjà chargées (date_echeance
  // réelle), jamais une donnée inventée : aucun endpoint d'agrégation dédié
  // n'existe, mais rien n'est nécessaire ici, tout est déjà en mémoire.
  const echeancesAVenir = useMemo(
    () => buildEcheancesAVenir(factures),
    [factures],
  );

  const joursAvantEcheance = useMemo(
    () => computeJoursRestants(ECHEANCE_RECEPTION_ELECTRONIQUE),
    [],
  );

  return (
    <>
      {/* Zone 1 — Command Strip (§5.1) : salutation réelle, contexte de
          conformité réel (aucune donnée inventée), action principale réelle,
          alerte réelle (échéance réglementaire connue). */}
      <section className="command-strip">
        <div className="command-strip__intro">
          <p className="eyebrow">{formatToday()}</p>
          <h1>{buildGreeting(utilisateur?.prenom)}</h1>
          <p className="command-strip__meta">
            <CheckCircle2 size={16} aria-hidden="true" />
            Réception électronique active · émission prête au format Factur-X
          </p>
        </div>

        <div className="command-strip__actions">
          <Link to="/app/factures/new" className="primary-btn">
            <Plus size={16} /> Nouvelle facture conforme
          </Link>

          <div className="deadline">
            {joursAvantEcheance > 0 ? `J-${joursAvantEcheance}` : "Échéance atteinte"}
            <br />
            <small>1er sept. 2026</small>
          </div>
        </div>
      </section>

      {/* Zone 2 — Indicateurs prioritaires (§5.2) : un indicateur primaire
          (Encaissé, l'accomplissement réel) + des indicateurs secondaires de
          poids visuel moindre — jamais 4 cartes clonées. Conformité ne
          s'affiche en vert que si elle vaut réellement 100 % (§7 : le vert
          est réservé à l'accomplissement réel, jamais un pourcentage partiel). */}
      <section className="metric-cluster" aria-label="Indicateurs prioritaires">
        <article className="metric-primary">
          <span>Encaissé · réel</span>
          <strong>{formatCurrency(kpis.encaisse)}</strong>
        </article>

        <div className="metric-secondary-list">
          <div className={`metric-secondary-row${kpis.enRetard > 0 ? " danger" : ""}`}>
            <span>En retard</span>
            <strong>{formatCurrency(kpis.enRetard)}</strong>
          </div>

          <div className="metric-secondary-row">
            <span>En attente</span>
            <strong>{formatCurrency(kpis.enAttente)}</strong>
          </div>

          <div className={`metric-secondary-row${kpis.conformite === 100 ? " success" : ""}`}>
            <span>Conformité</span>
            <strong>{kpis.conformite}%</strong>
          </div>
        </div>
      </section>

      {/* Zone 3 — Échéances/Attention (§5.3), élevée : données réelles,
          priorité visuelle retard réel > échéance proche (déjà portée par
          .status.danger/.status.warning, rouge réservé au vrai retard). */}
      <section>
        <SectionHeading
          title="Échéances à venir"
          subtitle="Dérivées de vos factures en attente de règlement"
        />

        {!isLoading && !error && echeancesAVenir.length === 0 && (
          <div className="state-card">
            Aucune échéance à suivre pour le moment.
          </div>
        )}

        {!isLoading && !error && echeancesAVenir.length > 0 && (
          <div className="invoice-list">
            {echeancesAVenir.map(({ facture, enRetard }) => (
              <div className="invoice-row" key={facture.id}>
                <div>
                  <strong>{getClientName(facture, clientsById)}</strong>

                  <span className="invoice-meta">
                    {facture.numero ?? "Brouillon"}
                  </span>
                </div>

                <div className="amount">
                  {formatCurrency(getFactureTotalTtc(facture))}
                </div>

                <div className={`status ${enRetard ? "danger" : "warning"}`}>
                  {enRetard
                    ? "En retard"
                    : formatEcheanceLabel(facture.date_echeance)}
                </div>
              </div>
            ))}
          </div>
        )}
      </section>

      {/* Zone 4 — Flux utile (§5.4) : seule donnée réelle disponible pour
          cette zone (factures récentes déjà chargées) — pas de flux
          d'activité inventé, pas d'agrégat cross-document fictif. */}
      <section>
        <SectionHeading
          title="Factures récentes"
          subtitle="Suivi du cycle de vie en temps réel"
          action={
            <Link to="/app/factures" className="section-action-link">
              Voir tout →
            </Link>
          }
        />

        {isLoading && (
          <div className="state-card">Chargement des factures...</div>
        )}

        {error && <div className="state-card error">{error}</div>}

        {!isLoading && !error && recentFactures.length === 0 && (
          <div className="state-card">Aucune facture pour le moment.</div>
        )}

        {!isLoading && !error && recentFactures.length > 0 && (
          <div className="invoice-list">
            {recentFactures.map((facture) => {
              const totalTtc = getFactureTotalTtc(facture);

              return (
                <div className="invoice-row" key={facture.id}>
                  <div>
                    <strong>{getClientName(facture, clientsById)}</strong>

                    <span className="invoice-meta">
                      {facture.numero ?? "Brouillon"} ·{" "}
                      {formatFactureFormat(facture.format)}
                    </span>
                  </div>

                  <div className="amount">{formatCurrency(totalTtc)}</div>

                  <div className={`status ${STATUS_VARIANTS[facture.statut]}`}>
                    {STATUS_LABELS[facture.statut]}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </section>
    </>
  );
}

function buildDashboardKpis(factures: Facture[]) {
  const facturesMetier = factures.filter(isFactureMetier);

  const encaisse = facturesMetier
    .filter((facture) => facture.statut === "encaissee")
    .reduce((sum, facture) => sum + getFactureTotalTtc(facture), 0);

  const enRetard = facturesMetier
    .filter(isFactureEnRetard)
    .reduce((sum, facture) => sum + getFactureTotalTtc(facture), 0);

  const enAttente = facturesMetier
    .filter(
      (facture) => isFactureEnAttente(facture) && !isFactureEnRetard(facture),
    )
    .reduce((sum, facture) => sum + getFactureTotalTtc(facture), 0);

  const facturesEmises = facturesMetier.filter(isFactureEmise);

  const facturesAvecArchives = facturesEmises.filter(
    (facture) => Boolean(facture.pdf_url) && Boolean(facture.xml_url),
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

type EcheanceItem = {
  facture: Facture;
  enRetard: boolean;
};

// Dérivé uniquement (§F6) : filtre les factures métier en attente de
// règlement qui portent une date_echeance réelle, trie par échéance la plus
// proche, limite l'affichage. Aucun calcul financier réinventé — les
// helpers isFactureEnAttente/isFactureEnRetard sont ceux déjà utilisés par
// les KPI ci-dessus, pas une nouvelle logique parallèle.
function hasDateEcheance(
  facture: Facture,
): facture is Facture & { date_echeance: string } {
  return Boolean(facture.date_echeance);
}

function buildEcheancesAVenir(factures: Facture[]): EcheanceItem[] {
  return factures
    .filter(isFactureMetier)
    .filter(isFactureEnAttente)
    .filter(hasDateEcheance)
    .sort(
      (a, b) =>
        new Date(a.date_echeance).getTime() -
        new Date(b.date_echeance).getTime(),
    )
    .slice(0, ECHEANCES_LIMIT)
    .map((facture) => ({ facture, enRetard: isFactureEnRetard(facture) }));
}

function formatEcheanceLabel(value: string | null) {
  if (!value) {
    return "Échéance";
  }

  return new Intl.DateTimeFormat("fr-FR", {
    day: "2-digit",
    month: "short",
  }).format(new Date(value));
}

function isFactureMetier(facture: Facture) {
  return getFactureTotalTtc(facture) > 0;
}

function isFactureEmise(facture: Facture) {
  return facture.statut !== "brouillon";
}

function isFactureEnAttente(facture: Facture) {
  return [
    "emise",
    "deposee",
    "recue",
    "mise_a_disposition",
    "approuvee",
    "en_litige",
  ].includes(facture.statut);
}

function isFactureEnRetard(facture: Facture) {
  if (!isFactureMetier(facture)) {
    return false;
  }

  if (!isFactureEnAttente(facture)) {
    return false;
  }

  if (!facture.date_echeance) {
    return false;
  }

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const dateEcheance = new Date(facture.date_echeance);
  dateEcheance.setHours(0, 0, 0, 0);

  return dateEcheance < today;
}

function getFactureTotalTtc(facture: Facture) {
  return toNumber(facture.total_ttc);
}

function getClientName(facture: Facture, clientsById: Record<string, Client>) {
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

function formatToday() {
  return new Intl.DateTimeFormat("fr-FR", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  }).format(new Date());
}

function buildGreeting(prenom: string | undefined) {
  return prenom ? `Bonjour ${prenom}` : "Bonjour";
}

function computeJoursRestants(echeance: Date) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const diffMs = echeance.getTime() - today.getTime();

  return Math.ceil(diffMs / (1000 * 60 * 60 * 24));
}