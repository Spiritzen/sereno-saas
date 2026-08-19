import { ChevronLeft, ChevronRight, Search, X } from "lucide-react";
import { useEffect, useState, type ChangeEventHandler, type FormEventHandler } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { listerFactures } from "../api/destinataireApi";
import { estErreurNonAuthentifie } from "../api/destinataireHttp";
import { getApiErrorMessage } from "../api/http";
import type {
  EspaceClientFactureListe,
  EspaceClientGroupeFournisseur,
  EspaceClientPagination,
  FiltreStatutPaiement,
  TriFactures,
} from "../types/espaceClient";

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

function formatDate(value: string | null) {
  if (!value) {
    return "—";
  }

  return new Intl.DateTimeFormat("fr-FR", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  }).format(new Date(value));
}

const STATUT_ENCAISSEMENT_LABELS: Record<
  EspaceClientFactureListe["statut_encaissement_local"],
  string
> = {
  non_payee: "En attente",
  partielle: "Partielle",
  soldee: "Payée",
};

// §1 execution_espace_client_sidebar_pagination_badge.txt — décision
// Sébastien : "en attente" (reste-à-payer > 0, donc non_payee ET partielle)
// en AMBRE, "payée" (soldee) reste au teal PAR DÉFAUT de .badge-paiement
// (aucune classe supplémentaire nécessaire pour ce cas).
function classeBadgePaiement(statut: EspaceClientFactureListe["statut_encaissement_local"]) {
  return statut === "soldee" ? "badge-paiement" : "badge-paiement badge-paiement--attente";
}

// Route authentifiée /espace-client (C2, structure §fix_espace_client_structure_page.txt,
// pagination/fournisseur_id §execution_espace_client_sidebar_pagination_badge.txt).
// Recherche/filtre/tri/page passent TOUJOURS par les paramètres de l'API —
// jamais un re-filtrage/pagination local d'un gros jeu chargé une fois.
export function EspaceClientFacturesPage() {
  const [searchParams] = useSearchParams();
  const fournisseurId = searchParams.get("fournisseur") ?? undefined;

  const [groupes, setGroupes] = useState<EspaceClientGroupeFournisseur[]>([]);
  const [pagination, setPagination] = useState<EspaceClientPagination | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [qInput, setQInput] = useState("");
  const [q, setQ] = useState("");
  const [statut, setStatut] = useState<FiltreStatutPaiement>("");
  const [tri, setTri] = useState<TriFactures>("date_desc");
  const [page, setPage] = useState(1);
  const [retryCount, setRetryCount] = useState(0);

  useEffect(() => {
    let ignore = false;

    void listerFactures({
      q: q || undefined,
      statut: statut || undefined,
      tri,
      fournisseur_id: fournisseurId,
      page,
    })
      .then((data) => {
        if (ignore) {
          return;
        }

        setGroupes(data.groupes);
        setPagination(data.pagination);
        setError(null);
      })
      .catch((apiError) => {
        if (ignore) {
          return;
        }

        // fix_espace_client_auth_deconnexion — un 401 n'est jamais une
        // erreur de DONNÉES : le contexte (invalidé par l'intercepteur, cf.
        // destinataireHttp.ts) et ProtectedDestinataireRoute redirigent déjà
        // vers la connexion. Afficher le message brut ici produisait le
        // bandeau "Authentification requise" en plein milieu de l'écran.
        if (estErreurNonAuthentifie(apiError)) {
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
  }, [q, statut, tri, fournisseurId, page, retryCount]);

  const handleSearchSubmit: FormEventHandler<HTMLFormElement> = (event) => {
    event.preventDefault();
    setIsLoading(true);
    setPage(1);
    setQ(qInput.trim());
  };

  const handleStatutChange: ChangeEventHandler<HTMLSelectElement> = (event) => {
    setIsLoading(true);
    setPage(1);
    setStatut(event.target.value as FiltreStatutPaiement);
  };

  const handleTriChange: ChangeEventHandler<HTMLSelectElement> = (event) => {
    setIsLoading(true);
    setPage(1);
    setTri(event.target.value as TriFactures);
  };

  function handleRetry() {
    setIsLoading(true);
    setRetryCount((count) => count + 1);
  }

  function handlePagePrecedente() {
    setIsLoading(true);
    setPage((current) => Math.max(1, current - 1));
  }

  function handlePageSuivante() {
    setIsLoading(true);
    setPage((current) => (pagination && current < pagination.total_pages ? current + 1 : current));
  }

  const aDesFiltresActifs = Boolean(q) || Boolean(statut) || Boolean(fournisseurId);

  return (
    <section className="factures-page">
      <div className="page-heading">
        <div>
          <span className="page-kicker">Espace client</span>
          <h1>Mes factures</h1>
          <p>Consultez les factures de vos fournisseurs Sereno et leur statut de paiement.</p>
        </div>
      </div>

      {fournisseurId && (
        <div className="list-summary">
          <span>Filtré sur un fournisseur</span>
          <Link to="/espace-client" className="secondary-btn">
            <X size={14} />
            Retirer le filtre
          </Link>
        </div>
      )}

      {/* §1 fix_espace_client_structure_page.txt — .list-toolbar/.search-field/
          .filter-select repris tels quels de FacturesPage.tsx (la barre de
          recherche/filtre de l'app), à la place de .line-form (form d'ajout
          de ligne de facture) qui écrasait les select et isolait le bouton
          "Rechercher" à droite sur sa propre ligne. */}
      <form className="list-toolbar" onSubmit={handleSearchSubmit}>
        <label className="search-field">
          <Search size={16} />
          <input
            type="search"
            value={qInput}
            placeholder="Numéro de facture ou fournisseur"
            onChange={(event) => setQInput(event.target.value)}
          />
        </label>

        <select
          className="filter-select"
          aria-label="Statut"
          value={statut}
          onChange={handleStatutChange}
        >
          <option value="">Tous les statuts</option>
          <option value="en_attente">En attente</option>
          <option value="payee">Payée</option>
        </select>

        <select className="filter-select" aria-label="Trier par" value={tri} onChange={handleTriChange}>
          <option value="date_desc">Date (plus récente)</option>
          <option value="date_asc">Date (plus ancienne)</option>
          <option value="montant_desc">Montant (décroissant)</option>
          <option value="montant_asc">Montant (croissant)</option>
        </select>

        <button type="submit" className="secondary-btn">
          Rechercher
        </button>
      </form>

      {isLoading && <div className="state-card">Chargement de vos factures...</div>}

      {!isLoading && error && (
        <div className="state-card error">
          {error}
          <div className="invoice-actions-row" style={{ marginTop: 12 }}>
            <button type="button" className="secondary-btn" onClick={handleRetry}>
              Réessayer
            </button>
          </div>
        </div>
      )}

      {!isLoading && !error && groupes.length === 0 && (
        <div className="state-card">
          {aDesFiltresActifs ? "Aucun résultat pour ces critères." : "Aucune facture pour le moment."}
        </div>
      )}

      {!isLoading &&
        !error &&
        groupes.map((groupe) => (
          // §1 fix_espace_client_structure_page.txt — .quick-step-card (déjà
          // utilisé par NewInvoicePage) au lieu de .kpi-card : .kpi-card strong
          // impose 26px/900 à TOUT <strong> descendant (pensé pour une carte à
          // une seule valeur), ce qui écrasait les montants du tableau de
          // factures imbriqué. .quick-step-card n'a pas cette règle.
          <details key={groupe.fournisseur.id} className="quick-step-card" open>
            <summary
              style={{
                cursor: "pointer",
                display: "flex",
                alignItems: "center",
                gap: 12,
                listStyle: "none",
              }}
            >
              {groupe.fournisseur.logo_url && (
                <img
                  src={groupe.fournisseur.logo_url}
                  alt=""
                  style={{ width: 24, height: 24, borderRadius: 4, objectFit: "contain" }}
                />
              )}
              <strong>{groupe.fournisseur.raison_sociale}</strong>
              <span className="pa-pill">
                {groupe.factures.length} facture{groupe.factures.length > 1 ? "s" : ""}
              </span>
            </summary>

            <div className="invoice-lines-table">
              <div className="invoice-lines-header">
                <span>Numéro</span>
                <span>Date</span>
                <span>Total TTC</span>
                <span>Reste à payer</span>
                <span>Statut</span>
              </div>

              {groupe.factures.map((facture) => (
                <Link
                  key={facture.id}
                  to={`/espace-client/factures/${facture.id}`}
                  className="invoice-lines-row"
                  style={{ textDecoration: "none", cursor: "pointer" }}
                >
                  <strong>{facture.numero ?? "—"}</strong>
                  <span>{formatDate(facture.date_emission)}</span>
                  <strong>{formatCurrency(toNumber(facture.total_ttc), facture.devise)}</strong>
                  <span>{formatCurrency(toNumber(facture.reste_a_payer), facture.devise)}</span>
                  <span className={classeBadgePaiement(facture.statut_encaissement_local)}>
                    {STATUT_ENCAISSEMENT_LABELS[facture.statut_encaissement_local]}
                  </span>
                </Link>
              ))}
            </div>
          </details>
        ))}

      {/* §3 — pagination RÉELLE (10/page côté API) : navigation sobre,
          réutilise .secondary-btn/.list-summary, même esprit que
          .pagination-row de FacturesPage.tsx. */}
      {!isLoading && !error && pagination && pagination.total_pages > 1 && (
        <div className="pagination-row">
          <button
            type="button"
            className="secondary-btn"
            disabled={pagination.page <= 1}
            onClick={handlePagePrecedente}
          >
            <ChevronLeft size={16} />
            Précédent
          </button>

          <span>
            Page {pagination.page}/{pagination.total_pages} · {pagination.total} facture
            {pagination.total > 1 ? "s" : ""}
          </span>

          <button
            type="button"
            className="secondary-btn"
            disabled={pagination.page >= pagination.total_pages}
            onClick={handlePageSuivante}
          >
            Suivant
            <ChevronRight size={16} />
          </button>
        </div>
      )}
    </section>
  );
}
