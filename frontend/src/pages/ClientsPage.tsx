import { Building2, Search, Users } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { listClients } from "../api/clientsApi";
import { getApiErrorMessage } from "../api/http";
import type { Client, ClientStatut, ClientType } from "../types/client";

type TypeFilter = "all" | ClientType;
type StatutFilter = "all" | ClientStatut;

const TYPE_LABELS: Record<ClientType, string> = {
  entreprise: "Entreprise",
  particulier: "Particulier",
  public: "Public",
};

const STATUT_LABELS: Record<ClientStatut, string> = {
  actif: "Actif",
  archive: "Archivé",
};

export function ClientsPage() {
  const [clients, setClients] = useState<Client[]>([]);
  const [search, setSearch] = useState("");
  const [typeFilter, setTypeFilter] = useState<TypeFilter>("all");
  const [statutFilter, setStatutFilter] = useState<StatutFilter>("all");
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    listClients()
      .then((clientsData) => {
        setClients(clientsData);
        setError(null);
      })
      .catch((apiError) => {
        setError(getApiErrorMessage(apiError));
      })
      .finally(() => {
        setIsLoading(false);
      });
  }, []);

  const filteredClients = useMemo(() => {
    const normalizedSearch = search.trim().toLowerCase();

    return clients.filter((client) => {
      const searchableText = [
        client.raison_sociale,
        client.siret,
        client.numero_tva,
        client.email,
        client.telephone,
        client.ville,
        client.code_postal,
        client.identifiant_routage_pa,
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();

      const matchesSearch =
        normalizedSearch.length === 0 ||
        searchableText.includes(normalizedSearch);

      const matchesType = typeFilter === "all" || client.type === typeFilter;

      const matchesStatut =
        statutFilter === "all" || client.statut === statutFilter;

      return matchesSearch && matchesType && matchesStatut;
    });
  }, [clients, search, typeFilter, statutFilter]);

  const actifsCount = useMemo(
    () => clients.filter((client) => client.statut === "actif").length,
    [clients],
  );

  const publicsCount = useMemo(
    () => clients.filter((client) => client.type === "public").length,
    [clients],
  );

  return (
    <section className="clients-page">
      <div className="page-heading">
        <div>
          <span className="page-kicker">Clients</span>
          <h1>Liste des clients</h1>
          <p>
            Centralisez les destinataires, leurs informations légales et leur
            routage PA.
          </p>
        </div>

        <button className="primary-btn" type="button" disabled>
          <Users size={16} /> Nouveau client bientôt
        </button>
      </div>

      <section className="client-kpi-grid">
        <article className="kpi-card">
          <span>Total clients</span>
          <strong>{clients.length}</strong>
        </article>

        <article className="kpi-card success">
          <span>Clients actifs</span>
          <strong>{actifsCount}</strong>
        </article>

        <article className="kpi-card">
          <span>Clients publics</span>
          <strong>{publicsCount}</strong>
        </article>
      </section>

      <div className="list-toolbar">
        <label className="search-field">
          <Search size={16} />
          <input
            type="search"
            value={search}
            placeholder="Rechercher par client, SIRET, ville, email..."
            onChange={(event) => setSearch(event.target.value)}
          />
        </label>

        <select
          className="filter-select"
          value={typeFilter}
          onChange={(event) => setTypeFilter(event.target.value as TypeFilter)}
        >
          <option value="all">Tous les types</option>
          <option value="entreprise">Entreprises</option>
          <option value="particulier">Particuliers</option>
          <option value="public">Publics</option>
        </select>

        <select
          className="filter-select"
          value={statutFilter}
          onChange={(event) =>
            setStatutFilter(event.target.value as StatutFilter)
          }
        >
          <option value="all">Tous les statuts</option>
          <option value="actif">Actifs</option>
          <option value="archive">Archivés</option>
        </select>
      </div>

      <div className="list-summary">
        <span>
          {filteredClients.length} client
          {filteredClients.length > 1 ? "s" : ""}
        </span>

        <strong>{filteredClients.length}</strong>
      </div>

      {isLoading && <div className="state-card">Chargement des clients...</div>}

      {error && <div className="state-card error">{error}</div>}

      {!isLoading && !error && filteredClients.length === 0 && (
        <div className="state-card">
          Aucun client ne correspond à votre recherche.
        </div>
      )}

      {!isLoading && !error && filteredClients.length > 0 && (
        <div className="clients-table">
          <div className="clients-table-header">
            <span>Client</span>
            <span>Identifiants</span>
            <span>Adresse</span>
            <span>Routage PA</span>
            <span>Statut</span>
          </div>

          {filteredClients.map((client) => (
            <article className="clients-table-row" key={client.id}>
              <div className="client-cell">
                <div className="client-icon">
                  <Building2 size={16} />
                </div>

                <div>
                  <strong>{client.raison_sociale}</strong>
                  <span>{TYPE_LABELS[client.type]}</span>
                </div>
              </div>

              <div className="muted-cell">
                <strong>{client.siret ?? "SIRET non renseigné"}</strong>
                <span>{client.numero_tva ?? "TVA non renseignée"}</span>
              </div>

              <div className="muted-cell">
                <strong>{formatAddress(client)}</strong>
                <span>{client.email ?? "Email non renseigné"}</span>
              </div>

              <div className="muted-cell">
                <strong>
                  {client.identifiant_routage_pa ?? "Routage non renseigné"}
                </strong>
                <span>{client.telephone ?? "Téléphone non renseigné"}</span>
              </div>

              <div
                className={`status ${
                  client.statut === "actif" ? "success" : "danger"
                }`}
              >
                {STATUT_LABELS[client.statut]}
              </div>
            </article>
          ))}
        </div>
      )}
    </section>
  );
}

function formatAddress(client: Client) {
  return [client.code_postal, client.ville, client.pays]
    .filter(Boolean)
    .join(" · ");
}