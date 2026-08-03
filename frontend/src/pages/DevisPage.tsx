import { ClipboardList, PencilLine, Plus, Search, Trash2 } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { listClients } from "../api/clientsApi";
import { deleteDevis, listDevis } from "../api/devisApi";
import { getApiErrorMessage } from "../api/http";
import { ConfirmModal } from "../components/ConfirmModal";
import type { Client } from "../types/client";
import type { Devis, DevisStatut } from "../types/devis";

type StatutFilter = "all" | DevisStatut;

const PAGE_SIZE = 10;

const STATUS_LABELS: Record<DevisStatut, string> = {
  brouillon: "Brouillon",
  envoye: "Envoyé",
  accepte: "Accepté",
  refuse: "Refusé",
};

const STATUS_VARIANTS: Record<
  DevisStatut,
  "success" | "info" | "warning" | "danger"
> = {
  brouillon: "warning",
  envoye: "info",
  accepte: "success",
  refuse: "danger",
};

const STATUS_OPTIONS: Array<{ value: StatutFilter; label: string }> = [
  { value: "all", label: "Tous les statuts" },
  { value: "brouillon", label: "Brouillons" },
  { value: "envoye", label: "Envoyés" },
  { value: "accepte", label: "Acceptés" },
  { value: "refuse", label: "Refusés" },
];

export function DevisPage() {
  const navigate = useNavigate();

  const [devisListe, setDevisListe] = useState<Devis[]>([]);
  const [clientsById, setClientsById] = useState<Record<string, Client>>({});
  const [search, setSearch] = useState("");
  const [statutFilter, setStatutFilter] = useState<StatutFilter>("all");
  const [currentPage, setCurrentPage] = useState(1);
  const [isLoading, setIsLoading] = useState(true);
  const [deletingDevisId, setDeletingDevisId] = useState<string | null>(null);
  const [devisToDelete, setDevisToDelete] = useState<Devis | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let ignore = false;

    void Promise.all([listDevis(), listClients()])
      .then(([devisData, clientsData]) => {
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

        setDevisListe(devisData);
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

  const filteredDevis = useMemo(() => {
    const normalizedSearch = search.trim().toLowerCase();

    return devisListe.filter((devis) => {
      const clientName = getClientName(devis, clientsById).toLowerCase();
      const numero = devis.numero?.toLowerCase() ?? "brouillon";
      const statutLabel = STATUS_LABELS[devis.statut].toLowerCase();

      const matchesSearch =
        normalizedSearch.length === 0 ||
        clientName.includes(normalizedSearch) ||
        numero.includes(normalizedSearch) ||
        statutLabel.includes(normalizedSearch);

      const matchesStatus =
        statutFilter === "all" || devis.statut === statutFilter;

      return matchesSearch && matchesStatus;
    });
  }, [devisListe, clientsById, search, statutFilter]);

  const totalPages = Math.max(1, Math.ceil(filteredDevis.length / PAGE_SIZE));
  const safeCurrentPage = Math.min(currentPage, totalPages);

  const paginatedDevis = useMemo(() => {
    const startIndex = (safeCurrentPage - 1) * PAGE_SIZE;
    const endIndex = startIndex + PAGE_SIZE;

    return filteredDevis.slice(startIndex, endIndex);
  }, [filteredDevis, safeCurrentPage]);

  const totalTtc = useMemo(
    () =>
      filteredDevis.reduce((sum, devis) => sum + getDevisTotalTtc(devis), 0),
    [filteredDevis],
  );

  function handleSearchChange(value: string) {
    setSearch(value);
    setCurrentPage(1);
  }

  function handleStatusFilterChange(value: StatutFilter) {
    setStatutFilter(value);
    setCurrentPage(1);
  }

  function handleOpenDevis(devis: Devis) {
    navigate(`/app/devis/${devis.id}`);
  }

  function handleAskDeleteDraft(devis: Devis) {
    if (devis.statut !== "brouillon") {
      setError("Seuls les brouillons peuvent être supprimés.");
      return;
    }

    setDevisToDelete(devis);
  }

  function handleCancelDeleteDraft() {
    if (deletingDevisId) {
      return;
    }

    setDevisToDelete(null);
  }

  async function handleConfirmDeleteDraft() {
    if (!devisToDelete) {
      return;
    }

    if (devisToDelete.statut !== "brouillon") {
      setError("Seuls les brouillons peuvent être supprimés.");
      setDevisToDelete(null);
      return;
    }

    setDeletingDevisId(devisToDelete.id);
    setError(null);

    try {
      await deleteDevis(devisToDelete.id);

      setDevisListe((current) =>
        current.filter((devis) => devis.id !== devisToDelete.id),
      );

      setDevisToDelete(null);
    } catch (apiError) {
      setError(getApiErrorMessage(apiError));
      setDevisToDelete(null);
    } finally {
      setDeletingDevisId(null);
    }
  }

  return (
    <section className="factures-page">
      <div className="page-heading">
        <div>
          <span className="page-kicker">Devis</span>
          <h1>Liste des devis</h1>
          <p>
            Suivez vos propositions commerciales, de la création à la
            conversion en facture.
          </p>
        </div>

        <Link to="/app/devis/new" className="primary-btn">
          <Plus size={16} /> Nouveau devis
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
          {filteredDevis.length} devis · page {safeCurrentPage}/{totalPages}
        </span>

        <strong>{formatCurrency(totalTtc)}</strong>
      </div>

      {isLoading && <div className="state-card">Chargement des devis...</div>}

      {error && <div className="state-card error">{error}</div>}

      {!isLoading && !error && filteredDevis.length === 0 && (
        <div className="state-card">
          {devisListe.length === 0
            ? "Aucun devis pour l’instant. Créez le premier pour envoyer une proposition commerciale à un client."
            : "Aucun devis ne correspond à votre recherche."}
        </div>
      )}

      {!isLoading && !error && filteredDevis.length > 0 && (
        <>
          <div className="factures-table">
            <div className="factures-table-header">
              <span>Document</span>
              <span>Client</span>
              <span>Validité</span>
              <span>Montant TTC</span>
              <span>Statut</span>
              <span>Actions</span>
            </div>

            {paginatedDevis.map((devis) => {
              const isDraft = devis.statut === "brouillon";

              return (
                <article className="factures-table-row" key={devis.id}>
                  <div className="document-cell">
                    <div className="document-icon">
                      <ClipboardList size={16} />
                    </div>

                    <div>
                      <strong>{devis.numero ?? "Brouillon"}</strong>
                      <span className="badge-devis">Devis</span>
                    </div>
                  </div>

                  <div className="muted-cell">
                    {getClientName(devis, clientsById)}
                  </div>

                  <div className="muted-cell">
                    {formatDate(devis.date_validite)}
                    {devis.expire && (
                      <span className="devis-accent-text"> · Expiré</span>
                    )}
                  </div>

                  <div className="amount-cell">
                    {formatCurrency(getDevisTotalTtc(devis))}
                  </div>

                  <div className={`status ${STATUS_VARIANTS[devis.statut]}`}>
                    {STATUS_LABELS[devis.statut]}
                  </div>

                  <div className="table-actions">
                    <button
                      type="button"
                      className="table-action-btn"
                      onClick={() => handleOpenDevis(devis)}
                    >
                      <PencilLine size={14} />
                      {isDraft ? "Reprendre" : "Ouvrir"}
                    </button>

                    {isDraft && (
                      <button
                        type="button"
                        className="table-action-btn danger"
                        disabled={deletingDevisId === devis.id}
                        onClick={() => handleAskDeleteDraft(devis)}
                      >
                        <Trash2 size={14} />
                        {deletingDevisId === devis.id
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
              onClick={() => setCurrentPage((page) => Math.max(1, page - 1))}
            >
              Précédent
            </button>

            <span>
              {paginatedDevis.length} affiché
              {paginatedDevis.length > 1 ? "s" : ""} sur{" "}
              {filteredDevis.length}
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

      <ConfirmModal
        open={Boolean(devisToDelete)}
        title="Supprimer ce brouillon ?"
        message={
          devisToDelete
            ? `Le brouillon ${devisToDelete.numero ?? "sans numéro"} sera supprimé définitivement. Cette action ne pourra pas être annulée.`
            : ""
        }
        confirmLabel={
          deletingDevisId ? "Suppression..." : "Supprimer le brouillon"
        }
        destructive
        isLoading={Boolean(deletingDevisId)}
        onCancel={handleCancelDeleteDraft}
        onConfirm={handleConfirmDeleteDraft}
      />
    </section>
  );
}

function getDevisTotalTtc(devis: Devis) {
  return toNumber(devis.total_ttc);
}

function getClientName(devis: Devis, clientsById: Record<string, Client>) {
  if (devis.client?.raison_sociale) {
    return devis.client.raison_sociale;
  }

  const client = clientsById[devis.client_id];

  if (client?.raison_sociale) {
    return client.raison_sociale;
  }

  return `Client ${devis.client_id.slice(0, 8)}`;
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
