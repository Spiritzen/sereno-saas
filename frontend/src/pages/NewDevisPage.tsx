import { ClipboardList, Plus, Search } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { listClients } from "../api/clientsApi";
import { createDevis } from "../api/devisApi";
import { getApiErrorMessage } from "../api/http";
import type { Client } from "../types/client";

function buildDefaultValiditeDate() {
  const date = new Date();
  date.setDate(date.getDate() + 30);

  return date.toISOString().slice(0, 10);
}

function getClientInitials(client: Client) {
  return client.raison_sociale
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase();
}

function formatClientLegalLine(client: Client) {
  if (client.siret) {
    return `SIRET ${client.siret}`;
  }

  return "SIRET non renseigné";
}

// Crée UNIQUEMENT le brouillon (client + objet + date de validité) puis
// navigue vers /app/devis/:id : c'est DevisDetailPage qui gère l'ajout des
// lignes, pour ne pas dupliquer cette logique dans deux pages (choix
// d'exécution — NewInvoicePage, elle, garde tout sur une seule page parce
// qu'elle n'a pas de page de détail séparée pour l'édition d'un brouillon).
export function NewDevisPage() {
  const navigate = useNavigate();

  const [clients, setClients] = useState<Client[]>([]);
  const [selectedClientId, setSelectedClientId] = useState<string | null>(
    null,
  );
  const [search, setSearch] = useState("");
  const [objet, setObjet] = useState("");
  const [dateValidite, setDateValidite] = useState(buildDefaultValiditeDate);

  const [isLoadingClients, setIsLoadingClients] = useState(true);
  const [isCreating, setIsCreating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let ignore = false;

    void listClients()
      .then((clientsData) => {
        if (!ignore) {
          setClients(clientsData);
          setError(null);
        }
      })
      .catch((apiError) => {
        if (!ignore) setError(getApiErrorMessage(apiError));
      })
      .finally(() => {
        if (!ignore) setIsLoadingClients(false);
      });

    return () => {
      ignore = true;
    };
  }, []);

  const activeClients = useMemo(
    () => clients.filter((client) => client.statut === "actif"),
    [clients],
  );

  const filteredClients = useMemo(() => {
    const normalizedSearch = search.trim().toLowerCase();

    return activeClients.filter((client) => {
      const searchableText = [
        client.raison_sociale,
        client.siret,
        client.numero_tva,
        client.email,
        client.ville,
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();

      return (
        normalizedSearch.length === 0 ||
        searchableText.includes(normalizedSearch)
      );
    });
  }, [activeClients, search]);

  const selectedClient = useMemo(
    () => activeClients.find((client) => client.id === selectedClientId) ?? null,
    [activeClients, selectedClientId],
  );

  async function handleCreateDraft() {
    if (!selectedClient) {
      setError("Sélectionnez un client avant de créer le devis.");
      return;
    }

    setError(null);
    setIsCreating(true);

    try {
      const devis = await createDevis({
        client_id: selectedClient.id,
        objet: objet.trim() || null,
        date_validite: dateValidite || null,
      });

      navigate(`/app/devis/${devis.id}`);
    } catch (apiError) {
      setError(getApiErrorMessage(apiError));
    } finally {
      setIsCreating(false);
    }
  }

  return (
    <section className="new-invoice-page">
      <div className="page-heading">
        <div>
          <span className="page-kicker">Nouveau devis</span>
          <h1>Créer un devis</h1>
          <p>
            Sélectionnez un client actif, définissez sa validité, puis
            ajoutez les lignes sur la page suivante.
          </p>
        </div>

        <span className="badge-devis">
          <ClipboardList size={14} /> Devis
        </span>
      </div>

      <div className="quick-create-layout">
        <section className="quick-create-main">
          <div className="quick-step-card">
            <div className="quick-step-header">
              <div>
                <span className="step-index">1</span>
                <h2>Choisir le destinataire</h2>
                <p>
                  Seuls les clients actifs sont proposés pour éviter d’envoyer
                  un devis à un destinataire archivé.
                </p>
              </div>
            </div>

            <label className="search-field">
              <Search size={16} />
              <input
                type="search"
                value={search}
                placeholder="Rechercher un client actif..."
                onChange={(event) => setSearch(event.target.value)}
              />
            </label>

            {isLoadingClients && (
              <div className="state-card">Chargement des clients...</div>
            )}

            {!isLoadingClients && filteredClients.length === 0 && (
              <div className="state-card">
                Aucun client actif ne correspond à votre recherche.
              </div>
            )}

            {!isLoadingClients && filteredClients.length > 0 && (
              <div className="client-picker-grid">
                {filteredClients.map((client) => (
                  <button
                    key={client.id}
                    type="button"
                    className={`client-choice-card ${
                      selectedClientId === client.id ? "selected" : ""
                    }`}
                    onClick={() => setSelectedClientId(client.id)}
                  >
                    <div className="client-choice-avatar">
                      {getClientInitials(client)}
                    </div>

                    <div>
                      <strong>{client.raison_sociale}</strong>
                      <span>{formatClientLegalLine(client)}</span>
                    </div>
                  </button>
                ))}
              </div>
            )}
          </div>

          <div className="quick-step-card">
            <div className="quick-step-header">
              <div>
                <span className="step-index">2</span>
                <h2>Objet et validité</h2>
                <p>Ces informations restent modifiables tant que le devis est en brouillon.</p>
              </div>
            </div>

            <label className="search-field" style={{ display: "block", marginBottom: 16 }}>
              Objet (optionnel)
              <input
                type="text"
                value={objet}
                placeholder="Ex : Refonte du site vitrine"
                onChange={(event) => setObjet(event.target.value)}
              />
            </label>

            <label className="search-field" style={{ display: "block" }}>
              Date de validité
              <input
                type="date"
                value={dateValidite}
                onChange={(event) => setDateValidite(event.target.value)}
              />
            </label>

            {error && <div className="state-card error">{error}</div>}

            <button
              type="button"
              className="primary-btn create-draft-btn"
              disabled={!selectedClient || isCreating}
              onClick={() => {
                void handleCreateDraft();
              }}
            >
              <Plus size={16} />
              {isCreating ? "Création..." : "Créer le brouillon"}
            </button>
          </div>
        </section>

        <aside className="quick-create-aside">
          <div className="compliance-panel">
            <div className="compliance-panel-title">
              <ClipboardList size={20} />
              <h2>Ce qui suit</h2>
            </div>

            <ul>
              <li>Client actif uniquement</li>
              <li>Lignes ajoutées sur la page suivante</li>
              <li>Totaux recalculés par Sereno</li>
              <li>Numéro DEV attribué à l’envoi, pas avant</li>
              <li>Aucune valeur légale tant que non converti</li>
            </ul>
          </div>
        </aside>
      </div>
    </section>
  );
}
