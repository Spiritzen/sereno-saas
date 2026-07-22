import {
  Archive,
  Building2,
  PencilLine,
  Plus,
  Search,
  X,
} from "lucide-react";
import { useEffect, useMemo, useState, type FormEventHandler } from "react";
import {
  archiveClient,
  createClient,
  listClients,
  updateClient,
} from "../api/clientsApi";
import { getApiErrorMessage } from "../api/http";
import { ModalShell } from "../components/ModalShell";
import type {
  Client,
  ClientInput,
  ClientStatut,
  ClientType,
} from "../types/client";

type TypeFilter = "all" | ClientType;
type StatutFilter = "all" | ClientStatut;

type ClientFormState = {
  type: ClientType;
  raison_sociale: string;
  siret: string;
  numero_tva: string;
  adresse_ligne1: string;
  adresse_ligne2: string;
  code_postal: string;
  ville: string;
  pays: string;
  email: string;
  telephone: string;
  identifiant_routage_pa: string;
  notes: string;
};

const TYPE_LABELS: Record<ClientType, string> = {
  entreprise: "Entreprise",
  particulier: "Particulier",
  public: "Public",
};

const STATUT_LABELS: Record<ClientStatut, string> = {
  actif: "Actif",
  archive: "Archivé",
};

const TYPE_HELP_TEXT: Record<ClientType, string> = {
  entreprise:
    "Client professionnel : SIRET obligatoire, TVA optionnelle selon le cas.",
  particulier:
    "Client particulier : SIRET et numéro de TVA non nécessaires pour aller vite.",
  public:
    "Client public : SIRET obligatoire, routage PA conseillé pour Chorus / PA.",
};

export function ClientsPage() {
  const [clients, setClients] = useState<Client[]>([]);
  const [search, setSearch] = useState("");
  const [typeFilter, setTypeFilter] = useState<TypeFilter>("all");
  const [statutFilter, setStatutFilter] = useState<StatutFilter>("all");

  const [isLoading, setIsLoading] = useState(true);
  const [isSavingClient, setIsSavingClient] = useState(false);
  const [archivingClientId, setArchivingClientId] = useState<string | null>(
    null,
  );

  const [error, setError] = useState<string | null>(null);
  const [modalError, setModalError] = useState<string | null>(null);

  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingClient, setEditingClient] = useState<Client | null>(null);
  const [form, setForm] = useState<ClientFormState>(buildEmptyClientForm());

  const [clientToArchive, setClientToArchive] = useState<Client | null>(null);

  const showLegalIdentifiers = form.type !== "particulier";

  useEffect(() => {
    let ignore = false;

    void listClients()
      .then((clientsData) => {
        if (ignore) {
          return;
        }

        setClients(sortClients(clientsData));
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

  const archivedCount = useMemo(
    () => clients.filter((client) => client.statut === "archive").length,
    [clients],
  );

  const publicsCount = useMemo(
    () => clients.filter((client) => client.type === "public").length,
    [clients],
  );

  function handleOpenCreateModal() {
    setEditingClient(null);
    setForm(buildEmptyClientForm());
    setModalError(null);
    setIsModalOpen(true);
  }

  function handleOpenEditModal(client: Client) {
    setEditingClient(client);
    setForm(buildClientFormFromClient(client));
    setModalError(null);
    setIsModalOpen(true);
  }

  function resetClientModal() {
    setIsModalOpen(false);
    setEditingClient(null);
    setForm(buildEmptyClientForm());
    setModalError(null);
  }

  function handleCloseModal() {
    if (isSavingClient) {
      return;
    }

    resetClientModal();
  }

  function handleClientTypeChange(type: ClientType) {
    setForm((currentForm) => ({
      ...currentForm,
      type,
      siret: type === "particulier" ? "" : currentForm.siret,
      numero_tva: type === "particulier" ? "" : currentForm.numero_tva,
      identifiant_routage_pa:
        type === "particulier" ? "" : currentForm.identifiant_routage_pa,
    }));

    setModalError(null);
  }

  function handleFieldChange<K extends keyof ClientFormState>(
    field: K,
    value: ClientFormState[K],
  ) {
    setForm((currentForm) => ({
      ...currentForm,
      [field]: value,
    }));
  }

  const handleSubmitClient: FormEventHandler<HTMLFormElement> = async (
    event,
  ) => {
    event.preventDefault();

    const validationError = validateClientForm(form);

    if (validationError) {
      setModalError(validationError);
      return;
    }

    setIsSavingClient(true);
    setModalError(null);

    try {
      const payload = buildClientPayload(form);

      if (editingClient) {
        const updatedClient = await updateClient(editingClient.id, payload);

        setClients((currentClients) =>
          sortClients(
            currentClients.map((client) =>
              client.id === updatedClient.id ? updatedClient : client,
            ),
          ),
        );
      } else {
        const createdClient = await createClient(payload);

        setClients((currentClients) =>
          sortClients([...currentClients, createdClient]),
        );
      }

      resetClientModal();
    } catch (apiError) {
      setModalError(getApiErrorMessage(apiError));
    } finally {
      setIsSavingClient(false);
    }
  };

  function handleAskArchiveClient(client: Client) {
    if (client.statut === "archive") {
      return;
    }

    setClientToArchive(client);
  }

  function handleCloseArchiveConfirmation() {
    if (archivingClientId) {
      return;
    }

    setClientToArchive(null);
  }

  async function handleConfirmArchiveClient() {
    if (!clientToArchive) {
      return;
    }

    setArchivingClientId(clientToArchive.id);
    setError(null);

    try {
      const archivedClient = await archiveClient(clientToArchive.id);

      setClients((currentClients) =>
        sortClients(
          currentClients.map((currentClient) =>
            currentClient.id === archivedClient.id
              ? archivedClient
              : currentClient,
          ),
        ),
      );

      setClientToArchive(null);
    } catch (apiError) {
      setError(getApiErrorMessage(apiError));
    } finally {
      setArchivingClientId(null);
    }
  }

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

        <button
          className="primary-btn"
          type="button"
          onClick={handleOpenCreateModal}
        >
          <Plus size={16} /> Nouveau client
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

        <article className="kpi-card danger">
          <span>Clients archivés</span>
          <strong>{archivedCount}</strong>
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
            <span>Actions</span>
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

              <div className="table-actions">
                <button
                  type="button"
                  className="table-action-btn"
                  onClick={() => handleOpenEditModal(client)}
                >
                  <PencilLine size={14} />
                  Modifier
                </button>

                {client.statut === "actif" && (
                  <button
                    type="button"
                    className="table-action-btn danger"
                    disabled={archivingClientId === client.id}
                    onClick={() => handleAskArchiveClient(client)}
                  >
                    <Archive size={14} />
                    {archivingClientId === client.id
                      ? "Archivage..."
                      : "Archiver"}
                  </button>
                )}
              </div>
            </article>
          ))}
        </div>
      )}

      <ModalShell
        open={isModalOpen}
        onClose={handleCloseModal}
        labelledBy="client-modal-title"
        isDismissDisabled={isSavingClient}
        surfaceClassName="client-modal"
      >
        <header className="modal-shell__header client-modal-header">
          <div>
            <span className="page-kicker">
              {editingClient ? "Modifier client" : "Nouveau client"}
            </span>
            <h2 id="client-modal-title">
              {editingClient
                ? editingClient.raison_sociale
                : "Créer un client"}
            </h2>
          </div>

          <button
            type="button"
            className="client-modal-close"
            onClick={handleCloseModal}
            aria-label="Fermer"
          >
            <X size={18} />
          </button>
        </header>

        <div className="modal-shell__body">
          <form
            id="client-modal-form"
            className="client-form"
            onSubmit={handleSubmitClient}
            noValidate
          >
              <div className="client-type-help-card">
                <strong>{TYPE_LABELS[form.type]}</strong>
                <span>{TYPE_HELP_TEXT[form.type]}</span>
              </div>

              <div className="client-form-grid">
                <div className="client-form-field">
                  <span>Type de client</span>

                  <div
                    className="client-type-selector"
                    role="group"
                    aria-label="Type de client"
                  >
                    {(["entreprise", "particulier", "public"] as ClientType[]).map(
                      (type) => (
                        <button
                          key={type}
                          type="button"
                          className={`client-type-option ${
                            form.type === type ? "selected" : ""
                          }`}
                          onClick={() => handleClientTypeChange(type)}
                        >
                          {TYPE_LABELS[type]}
                        </button>
                      ),
                    )}
                  </div>
                </div>

                <label>
                  {form.type === "particulier"
                    ? "Nom complet"
                    : "Raison sociale"}{" "}
                  <span className="required-mark">*</span>
                  <input
                    type="text"
                    value={form.raison_sociale}
                    placeholder={
                      form.type === "particulier"
                        ? "Ex : Camille Morel"
                        : form.type === "public"
                          ? "Ex : Mairie d’Amiens"
                          : "Ex : Atelier NovaTech SAS"
                    }
                    onChange={(event) =>
                      handleFieldChange("raison_sociale", event.target.value)
                    }
                  />
                </label>

                {showLegalIdentifiers && (
                  <>
                    <label>
                      SIRET <span className="required-mark">*</span>
                      <input
                        type="text"
                        value={form.siret}
                        placeholder="14 chiffres"
                        inputMode="numeric"
                        maxLength={17}
                        onChange={(event) =>
                          handleFieldChange("siret", event.target.value)
                        }
                      />
                    </label>

                    <label>
                      Numéro TVA
                      <span className="optional-mark">Optionnel</span>
                      <input
                        type="text"
                        value={form.numero_tva}
                        placeholder="Ex : FR..."
                        onChange={(event) =>
                          handleFieldChange("numero_tva", event.target.value)
                        }
                      />
                    </label>
                  </>
                )}

                <label className="client-form-wide">
                  Adresse ligne 1 <span className="required-mark">*</span>
                  <input
                    type="text"
                    value={form.adresse_ligne1}
                    placeholder="10 rue des Tests"
                    onChange={(event) =>
                      handleFieldChange("adresse_ligne1", event.target.value)
                    }
                  />
                </label>

                <label className="client-form-wide">
                  Adresse ligne 2
                  <span className="optional-mark">Optionnel</span>
                  <input
                    type="text"
                    value={form.adresse_ligne2}
                    placeholder="Bâtiment, étage..."
                    onChange={(event) =>
                      handleFieldChange("adresse_ligne2", event.target.value)
                    }
                  />
                </label>

                <label>
                  Code postal <span className="required-mark">*</span>
                  <input
                    type="text"
                    value={form.code_postal}
                    placeholder="80000"
                    onChange={(event) =>
                      handleFieldChange("code_postal", event.target.value)
                    }
                  />
                </label>

                <label>
                  Ville <span className="required-mark">*</span>
                  <input
                    type="text"
                    value={form.ville}
                    placeholder="Amiens"
                    onChange={(event) =>
                      handleFieldChange("ville", event.target.value)
                    }
                  />
                </label>

                <label>
                  Pays <span className="required-mark">*</span>
                  <input
                    type="text"
                    value={form.pays}
                    placeholder="FR"
                    maxLength={2}
                    onChange={(event) =>
                      handleFieldChange("pays", event.target.value)
                    }
                  />
                </label>

                <label>
                  Email
                  <span className="optional-mark">Optionnel</span>
                  <input
                    type="text"
                    value={form.email}
                    placeholder={
                      form.type === "particulier"
                        ? "camille@example.fr"
                        : "client@example.fr"
                    }
                    onChange={(event) =>
                      handleFieldChange("email", event.target.value)
                    }
                  />
                </label>

                <label>
                  Téléphone
                  <span className="optional-mark">Optionnel</span>
                  <input
                    type="text"
                    value={form.telephone}
                    placeholder="0102030405"
                    onChange={(event) =>
                      handleFieldChange("telephone", event.target.value)
                    }
                  />
                </label>

                {form.type !== "particulier" && (
                  <label>
                    Routage PA
                    <span className="optional-mark">
                      {form.type === "public" ? "Conseillé" : "Optionnel"}
                    </span>
                    <input
                      type="text"
                      value={form.identifiant_routage_pa}
                      placeholder={
                        form.type === "public"
                          ? "Ex : CHORUS-PRO-SERVICE"
                          : "Identifiant plateforme agréée"
                      }
                      onChange={(event) =>
                        handleFieldChange(
                          "identifiant_routage_pa",
                          event.target.value,
                        )
                      }
                    />
                  </label>
                )}

                <label className="client-form-wide">
                  Notes
                  <span className="optional-mark">Optionnel</span>
                  <textarea
                    value={form.notes}
                    placeholder="Notes internes..."
                    rows={3}
                    onChange={(event) =>
                      handleFieldChange("notes", event.target.value)
                    }
                  />
                </label>
              </div>

              {modalError && <div className="state-card error">{modalError}</div>}
          </form>
        </div>

        <footer className="modal-shell__footer client-modal-actions">
          <button
            type="button"
            className="secondary-btn"
            onClick={handleCloseModal}
            disabled={isSavingClient}
          >
            Annuler
          </button>

          <button
            type="submit"
            form="client-modal-form"
            className="primary-btn"
            disabled={isSavingClient}
          >
            {isSavingClient
              ? "Enregistrement..."
              : editingClient
                ? "Enregistrer"
                : "Créer le client"}
          </button>
        </footer>
      </ModalShell>

      <ModalShell
        open={Boolean(clientToArchive)}
        onClose={handleCloseArchiveConfirmation}
        labelledBy="archive-client-title"
        isDismissDisabled={Boolean(archivingClientId)}
        surfaceClassName="confirmation-modal"
      >
        <div className="modal-shell__header">
          <div className="confirmation-icon danger">
            <Archive size={22} />
          </div>

          <div>
            <span className="page-kicker">Archivage client</span>
            <h2 id="archive-client-title">Archiver ce client ?</h2>
          </div>
        </div>

        <div className="modal-shell__body">
          <p>
            Le client <strong>{clientToArchive?.raison_sociale}</strong> ne
            sera plus proposé dans les nouvelles factures. Ses documents
            existants resteront conservés.
          </p>
        </div>

        <footer className="modal-shell__footer confirmation-actions">
          <button
            type="button"
            className="secondary-btn"
            disabled={Boolean(archivingClientId)}
            onClick={handleCloseArchiveConfirmation}
          >
            Annuler
          </button>

          <button
            type="button"
            className="danger-btn"
            disabled={Boolean(archivingClientId)}
            onClick={handleConfirmArchiveClient}
          >
            {archivingClientId ? "Archivage..." : "Archiver"}
          </button>
        </footer>
      </ModalShell>
    </section>
  );
}

function buildEmptyClientForm(): ClientFormState {
  return {
    type: "entreprise",
    raison_sociale: "",
    siret: "",
    numero_tva: "",
    adresse_ligne1: "",
    adresse_ligne2: "",
    code_postal: "",
    ville: "",
    pays: "FR",
    email: "",
    telephone: "",
    identifiant_routage_pa: "",
    notes: "",
  };
}

function buildClientFormFromClient(client: Client): ClientFormState {
  return {
    type: client.type,
    raison_sociale: client.raison_sociale ?? "",
    siret: client.siret ?? "",
    numero_tva: client.numero_tva ?? "",
    adresse_ligne1: client.adresse_ligne1 ?? "",
    adresse_ligne2: client.adresse_ligne2 ?? "",
    code_postal: client.code_postal ?? "",
    ville: client.ville ?? "",
    pays: client.pays ?? "FR",
    email: client.email ?? "",
    telephone: client.telephone ?? "",
    identifiant_routage_pa: client.identifiant_routage_pa ?? "",
    notes: client.notes ?? "",
  };
}

function buildClientPayload(form: ClientFormState): ClientInput {
  const isParticulier = form.type === "particulier";

  return {
    type: form.type,
    raison_sociale: form.raison_sociale.trim(),
    siret: isParticulier
      ? null
      : normalizeOptionalValue(normalizeSiret(form.siret)),
    numero_tva: isParticulier ? null : normalizeOptionalValue(form.numero_tva),
    adresse_ligne1: form.adresse_ligne1.trim(),
    adresse_ligne2: normalizeOptionalValue(form.adresse_ligne2),
    code_postal: form.code_postal.trim(),
    ville: form.ville.trim(),
    pays: form.pays.trim().toUpperCase() || "FR",
    email: normalizeOptionalValue(form.email),
    telephone: normalizeOptionalValue(form.telephone),
    identifiant_routage_pa: isParticulier
      ? null
      : normalizeOptionalValue(form.identifiant_routage_pa),
    notes: normalizeOptionalValue(form.notes),
  };
}

function validateClientForm(form: ClientFormState) {
  const siret = normalizeSiret(form.siret);
  const pays = form.pays.trim().toUpperCase();
  const email = normalizeOptionalValue(form.email);

  if (form.raison_sociale.trim().length < 2) {
    return "La raison sociale ou le nom doit contenir au moins 2 caractères.";
  }

  if (form.adresse_ligne1.trim().length === 0) {
    return "L’adresse ligne 1 est obligatoire.";
  }

  if (form.code_postal.trim().length === 0) {
    return "Le code postal est obligatoire.";
  }

  if (form.ville.trim().length === 0) {
    return "La ville est obligatoire.";
  }

  if (pays.length !== 2) {
    return "Le pays doit être un code ISO à 2 lettres, par exemple FR.";
  }

  if (form.type !== "particulier" && siret.length !== 14) {
    return "Le SIRET est obligatoire et doit contenir 14 chiffres pour une entreprise ou un client public.";
  }

  if (email && !isValidEmail(email)) {
    return "L’email renseigné n’est pas valide.";
  }

  return null;
}

function isValidEmail(value: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function normalizeOptionalValue(value: string) {
  const trimmedValue = value.trim();

  return trimmedValue.length > 0 ? trimmedValue : null;
}

function normalizeSiret(value: string) {
  return value.replace(/\s/g, "");
}

function sortClients(clients: Client[]) {
  return [...clients].sort((firstClient, secondClient) =>
    firstClient.raison_sociale.localeCompare(secondClient.raison_sociale),
  );
}

function formatAddress(client: Client) {
  return [client.code_postal, client.ville, client.pays]
    .filter(Boolean)
    .join(" · ");
}