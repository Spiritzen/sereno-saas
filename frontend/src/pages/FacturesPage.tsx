import {
  ExternalLink,
  FileText,
  PencilLine,
  Plus,
  Search,
  Trash2,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { listClients } from "../api/clientsApi";
import {
  deleteFacture,
  getFacturePdfUrl,
  getFactureXmlUrl,
  listFactures,
} from "../api/facturesApi";
import { getApiErrorMessage } from "../api/http";
import type { Client } from "../types/client";
import type { Facture, FactureStatut } from "../types/facture";

type StatutFilter = "all" | FactureStatut;

const PAGE_SIZE = 10;

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

const STATUS_OPTIONS: Array<{ value: StatutFilter; label: string }> = [
  { value: "all", label: "Tous les statuts" },
  { value: "brouillon", label: "Brouillons" },
  { value: "emise", label: "Émises" },
  { value: "encaissee", label: "Paiement reçu" },
  { value: "en_litige", label: "En litige" },
  { value: "annulee", label: "Annulées" },
];

export function FacturesPage() {
  const navigate = useNavigate();

  const [factures, setFactures] = useState<Facture[]>([]);
  const [clientsById, setClientsById] = useState<Record<string, Client>>({});
  const [search, setSearch] = useState("");
  const [statutFilter, setStatutFilter] = useState<StatutFilter>("all");
  const [currentPage, setCurrentPage] = useState(1);
  const [isLoading, setIsLoading] = useState(true);
  const [deletingFactureId, setDeletingFactureId] = useState<string | null>(
    null,
  );
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let ignore = false;

    void Promise.all([listFactures(), listClients()])
      .then(([facturesData, clientsData]) => {
        if (ignore) {
          return;
        }

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
        if (ignore) {
          return;
        }

        setError(getApiErrorMessage(apiError));
      })
      .finally(() => {
        if (ignore) {
          return;
        }

        setIsLoading(false);
      });

    return () => {
      ignore = true;
    };
  }, []);

  const filteredFactures = useMemo(() => {
    const normalizedSearch = search.trim().toLowerCase();

    return factures.filter((facture) => {
      const clientName = getClientName(facture, clientsById).toLowerCase();
      const numero = facture.numero?.toLowerCase() ?? "brouillon";
      const statutLabel = STATUS_LABELS[facture.statut].toLowerCase();

      const matchesSearch =
        normalizedSearch.length === 0 ||
        clientName.includes(normalizedSearch) ||
        numero.includes(normalizedSearch) ||
        statutLabel.includes(normalizedSearch);

      const matchesStatus =
        statutFilter === "all" || facture.statut === statutFilter;

      return matchesSearch && matchesStatus;
    });
  }, [factures, clientsById, search, statutFilter]);

  const totalPages = Math.max(
    1,
    Math.ceil(filteredFactures.length / PAGE_SIZE),
  );

  const safeCurrentPage = Math.min(currentPage, totalPages);

  const paginatedFactures = useMemo(() => {
    const startIndex = (safeCurrentPage - 1) * PAGE_SIZE;
    const endIndex = startIndex + PAGE_SIZE;

    return filteredFactures.slice(startIndex, endIndex);
  }, [filteredFactures, safeCurrentPage]);

  const totalTtc = useMemo(
    () =>
      filteredFactures.reduce(
        (sum, facture) => sum + getFactureTotalTtc(facture),
        0,
      ),
    [filteredFactures],
  );

  function handleSearchChange(value: string) {
    setSearch(value);
    setCurrentPage(1);
  }

  function handleStatusFilterChange(value: StatutFilter) {
    setStatutFilter(value);
    setCurrentPage(1);
  }

  function handleOpenFacture(facture: Facture) {
    navigate(`/app/factures/${facture.id}`);
  }

  function handleOpenPdf(facture: Facture) {
    window.open(getFacturePdfUrl(facture.id), "_blank", "noopener,noreferrer");
  }

  function handleOpenXml(facture: Facture) {
    window.open(getFactureXmlUrl(facture.id), "_blank", "noopener,noreferrer");
  }

  async function handleDeleteDraft(facture: Facture) {
    if (facture.statut !== "brouillon") {
      setError("Seuls les brouillons peuvent être supprimés.");
      return;
    }

    const confirmed = window.confirm(
      "Supprimer ce brouillon ? Cette action est définitive.",
    );

    if (!confirmed) {
      return;
    }

    setDeletingFactureId(facture.id);
    setError(null);

    try {
      await deleteFacture(facture.id);
      setFactures((currentFactures) =>
        currentFactures.filter(
          (currentFacture) => currentFacture.id !== facture.id,
        ),
      );
    } catch (apiError) {
      setError(getApiErrorMessage(apiError));
    } finally {
      setDeletingFactureId(null);
    }
  }

  return (
    <section className="factures-page">
      <div className="page-heading">
        <div>
          <span className="page-kicker">Facturation</span>
          <h1>Liste des factures</h1>
          <p>
            Consultez les brouillons, les factures émises et le cycle de vie de
            chaque document.
          </p>
        </div>

        <Link to="/app/factures/new" className="primary-btn">
          <Plus size={16} /> Nouvelle facture
        </Link>
      </div>

      <div className="list-toolbar">
        <label className="search-field">
          <Search size={16} />
          <input
            type="search"
            value={search}
            placeholder="Rechercher par client, numéro ou statut..."
            onChange={(event) => handleSearchChange(event.target.value)}
          />
        </label>

        <select
          className="filter-select"
          value={statutFilter}
          onChange={(event) =>
            handleStatusFilterChange(event.target.value as StatutFilter)
          }
        >
          {STATUS_OPTIONS.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      </div>

      <div className="list-summary">
        <span>
          {filteredFactures.length} facture
          {filteredFactures.length > 1 ? "s" : ""} · page {safeCurrentPage}/
          {totalPages}
        </span>

        <strong>{formatCurrency(totalTtc)}</strong>
      </div>

      {isLoading && (
        <div className="state-card">Chargement des factures...</div>
      )}

      {error && <div className="state-card error">{error}</div>}

      {!isLoading && !error && filteredFactures.length === 0 && (
        <div className="state-card">
          Aucune facture ne correspond à votre recherche.
        </div>
      )}

      {!isLoading && !error && filteredFactures.length > 0 && (
        <>
          <div className="factures-table">
            <div className="factures-table-header">
              <span>Document</span>
              <span>Client</span>
              <span>Échéance</span>
              <span>Montant TTC</span>
              <span>Statut</span>
              <span>Actions</span>
            </div>

            {paginatedFactures.map((facture) => {
              const isDraft = facture.statut === "brouillon";
              const hasPdf = Boolean(facture.pdf_url);
              const hasXml = Boolean(facture.xml_url);

              return (
                <article className="factures-table-row" key={facture.id}>
                  <div className="document-cell">
                    <div className="document-icon">
                      <FileText size={16} />
                    </div>

                    <div>
                      <strong>{facture.numero ?? "Brouillon"}</strong>
                      <span>{formatFactureFormat(facture.format)}</span>
                    </div>
                  </div>

                  <div className="muted-cell">
                    {getClientName(facture, clientsById)}
                  </div>

                  <div className="muted-cell">
                    {formatDate(facture.date_echeance)}
                  </div>

                  <div className="amount-cell">
                    {formatCurrency(getFactureTotalTtc(facture))}
                  </div>

                  <div className={`status ${STATUS_VARIANTS[facture.statut]}`}>
                    {STATUS_LABELS[facture.statut]}
                  </div>

                  <div className="table-actions">
                    <button
                      type="button"
                      className="table-action-btn"
                      onClick={() => handleOpenFacture(facture)}
                    >
                      <PencilLine size={14} />
                      {isDraft ? "Reprendre" : "Ouvrir"}
                    </button>

                    {hasPdf && (
                      <button
                        type="button"
                        className="table-action-btn"
                        onClick={() => handleOpenPdf(facture)}
                      >
                        <ExternalLink size={14} />
                        PDF
                      </button>
                    )}

                    {hasXml && (
                      <button
                        type="button"
                        className="table-action-btn"
                        onClick={() => handleOpenXml(facture)}
                      >
                        <ExternalLink size={14} />
                        XML
                      </button>
                    )}

                    {isDraft && (
                      <button
                        type="button"
                        className="table-action-btn danger"
                        disabled={deletingFactureId === facture.id}
                        onClick={() => handleDeleteDraft(facture)}
                      >
                        <Trash2 size={14} />
                        {deletingFactureId === facture.id
                          ? "Suppression..."
                          : "Supprimer"}
                      </button>
                    )}
                  </div>
                </article>
              );
            })}
          </div>

          <div className="pagination-row">
            <button
              type="button"
              className="secondary-btn"
              disabled={safeCurrentPage <= 1}
              onClick={() =>
                setCurrentPage((page) => Math.max(1, page - 1))
              }
            >
              Précédent
            </button>

            <span>
              {paginatedFactures.length} affichée
              {paginatedFactures.length > 1 ? "s" : ""} sur{" "}
              {filteredFactures.length}
            </span>

            <button
              type="button"
              className="secondary-btn"
              disabled={safeCurrentPage >= totalPages}
              onClick={() =>
                setCurrentPage((page) => Math.min(totalPages, page + 1))
              }
            >
              Suivant
            </button>
          </div>
        </>
      )}
    </section>
  );
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

function formatFactureFormat(format: Facture["format"] | null | undefined) {
  const labels = {
    factur_x: "Factur-X",
    ubl: "UBL",
    cii: "CII",
  };

  if (!format) {
    return "Format inconnu";
  }

  return labels[format] ?? format;
}

function formatDate(value: string | null | undefined) {
  if (!value) {
    return "Non renseignée";
  }

  return new Intl.DateTimeFormat("fr-FR", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  }).format(new Date(value));
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