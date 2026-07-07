import {
  CheckCircle2,
  CirclePlus,
  ExternalLink,
  FileText,
  Plus,
  Search,
  Send,
  ShieldCheck,
} from "lucide-react";
import { useEffect, useMemo, useState, type FormEventHandler } from "react";
import { listClients } from "../api/clientsApi";
import {
  createFacture,
  emettreFacture,
  getConformiteFacture,
  getFacturePdfUrl,
  getFactureXmlUrl,
} from "../api/facturesApi";
import { getApiErrorMessage } from "../api/http";
import {
  createLigneFacture,
  listLignesFacture,
} from "../api/lignesFactureApi";
import type { Client } from "../types/client";
import type { ConformiteResult } from "../types/conformite";
import type { Facture } from "../types/facture";
import type { LigneFacture } from "../types/ligneFacture";

export function NewInvoicePage() {
  const [clients, setClients] = useState<Client[]>([]);
  const [selectedClientId, setSelectedClientId] = useState<string | null>(null);
  const [createdFacture, setCreatedFacture] = useState<Facture | null>(null);
  const [lignes, setLignes] = useState<LigneFacture[]>([]);
  const [conformite, setConformite] = useState<ConformiteResult | null>(null);

  const [search, setSearch] = useState("");
  const [designation, setDesignation] = useState("");
  const [quantite, setQuantite] = useState("1");
  const [prixUnitaireHt, setPrixUnitaireHt] = useState("");
  const [tauxTva, setTauxTva] = useState("20");

  const [isLoadingClients, setIsLoadingClients] = useState(true);
  const [isCreating, setIsCreating] = useState(false);
  const [isAddingLine, setIsAddingLine] = useState(false);
  const [isCheckingConformite, setIsCheckingConformite] = useState(false);
  const [isEmitting, setIsEmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const isEmitted = createdFacture ? createdFacture.statut !== "brouillon" : false;

  const canEmit =
    Boolean(createdFacture) &&
    lignes.length > 0 &&
    conformite?.conforme === true &&
    !isEmitted;

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
        client.identifiant_routage_pa,
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
      setError("Sélectionnez un client avant de créer la facture.");
      return;
    }

    setError(null);
    setIsCreating(true);

    try {
      const facture = await createFacture({
        client_id: selectedClient.id,
        date_echeance: buildDefaultDueDate(),
        conditions_paiement: "Paiement à 30 jours",
        mentions: null,
      });

      setCreatedFacture(facture);
      setLignes(facture.lignes_facture ?? []);
      setConformite(null);
    } catch (apiError) {
      setError(getApiErrorMessage(apiError));
    } finally {
      setIsCreating(false);
    }
  }

  const handleAddLine: FormEventHandler<HTMLFormElement> = async (event) => {
    event.preventDefault();

    if (!createdFacture) {
      setError("Créez d’abord un brouillon avant d’ajouter une ligne.");
      return;
    }

    if (isEmitted) {
      setError("Cette facture est déjà émise. Elle ne peut plus être modifiée.");
      return;
    }

    const parsedQuantite = parseDecimal(quantite);
    const parsedPrixUnitaireHt = parseDecimal(prixUnitaireHt);
    const parsedTauxTva = parseDecimal(tauxTva);

    if (designation.trim().length < 2) {
      setError("La désignation doit contenir au moins 2 caractères.");
      return;
    }

    if (parsedQuantite <= 0) {
      setError("La quantité doit être supérieure à 0.");
      return;
    }

    if (parsedPrixUnitaireHt <= 0) {
      setError("Le prix unitaire HT doit être supérieur à 0.");
      return;
    }

    if (parsedTauxTva < 0) {
      setError("Le taux de TVA doit être positif ou nul.");
      return;
    }

    setError(null);
    setIsAddingLine(true);

    try {
      const updatedFacture = await createLigneFacture(createdFacture.id, {
        designation: designation.trim(),
        quantite: parsedQuantite,
        prix_unitaire_ht: parsedPrixUnitaireHt,
        taux_tva: parsedTauxTva,
        position: lignes.length + 1,
      });

      const updatedLignes = await listLignesFacture(createdFacture.id);

      setCreatedFacture(updatedFacture);
      setLignes(updatedLignes);
      setConformite(null);

      setDesignation("");
      setQuantite("1");
      setPrixUnitaireHt("");
      setTauxTva("20");
    } catch (apiError) {
      setError(getApiErrorMessage(apiError));
    } finally {
      setIsAddingLine(false);
    }
  };

  async function handleCheckConformite() {
    if (!createdFacture) {
      setError("Créez d’abord un brouillon avant de vérifier la conformité.");
      return;
    }

    if (lignes.length === 0) {
      setError("Ajoutez au moins une ligne avant de vérifier la conformité.");
      return;
    }

    setError(null);
    setIsCheckingConformite(true);

    try {
      const result = await getConformiteFacture(createdFacture.id);
      setConformite(result);
    } catch (apiError) {
      setError(getApiErrorMessage(apiError));
    } finally {
      setIsCheckingConformite(false);
    }
  }

  async function handleEmitFacture() {
    if (!createdFacture) {
      setError("Créez d’abord un brouillon avant d’émettre la facture.");
      return;
    }

    if (!conformite?.conforme) {
      setError("Vérifiez la conformité avant d’émettre la facture.");
      return;
    }

    setError(null);
    setIsEmitting(true);

    try {
      const emittedFacture = await emettreFacture(createdFacture.id);
      const updatedLignes = await listLignesFacture(createdFacture.id);

      setCreatedFacture(emittedFacture);
      setLignes(updatedLignes);
    } catch (apiError) {
      setError(getApiErrorMessage(apiError));
    } finally {
      setIsEmitting(false);
    }
  }

  function handleOpenPdf() {
    if (!createdFacture) {
      return;
    }

    window.open(getFacturePdfUrl(createdFacture.id), "_blank", "noopener,noreferrer");
  }

  function handleOpenXml() {
    if (!createdFacture) {
      return;
    }

    window.open(getFactureXmlUrl(createdFacture.id), "_blank", "noopener,noreferrer");
  }

  return (
    <section className="new-invoice-page">
      <div className="page-heading">
        <div>
          <span className="page-kicker">Nouvelle facture</span>
          <h1>Créer une facture en 2 clics</h1>
          <p>
            Sélectionnez un client actif, créez un brouillon, puis ajoutez les
            lignes de facturation.
          </p>
        </div>

        <span className="pa-pill">
          <ShieldCheck size={14} /> Workflow sécurisé
        </span>
      </div>

      <div className="quick-create-layout">
        <section className="quick-create-main">
          {!createdFacture && (
            <>
              <div className="quick-step-card">
                <div className="quick-step-header">
                  <div>
                    <span className="step-index">1</span>
                    <h2>Choisir le destinataire</h2>
                    <p>
                      Seuls les clients actifs sont proposés pour éviter
                      d’émettre une facture vers un destinataire archivé.
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
                          <small>{formatClientRouting(client)}</small>
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
                    <h2>Créer le brouillon</h2>
                    <p>
                      Sereno prépare la facture avec une échéance à 30 jours.
                    </p>
                  </div>
                </div>

                <div className="draft-preview-card">
                  <div className="document-icon">
                    <FileText size={18} />
                  </div>

                  <div>
                    <strong>
                      {selectedClient
                        ? `Facture pour ${selectedClient.raison_sociale}`
                        : "Aucun client sélectionné"}
                    </strong>

                    <span>
                      Échéance prévue : {formatDate(buildDefaultDueDate())}
                    </span>
                  </div>
                </div>

                {error && <div className="state-card error">{error}</div>}

                <button
                  type="button"
                  className="primary-btn create-draft-btn"
                  disabled={!selectedClient || isCreating}
                  onClick={handleCreateDraft}
                >
                  <Plus size={16} />
                  {isCreating ? "Création..." : "Créer le brouillon"}
                </button>
              </div>
            </>
          )}

          {createdFacture && (
            <div className="invoice-builder-card">
              <div className="invoice-builder-header">
                <div>
                  <span className="page-kicker">
                    {createdFacture.numero ?? "Brouillon enregistré"}
                  </span>
                  <h2>
                    {getCreatedFactureClientName(
                      createdFacture,
                      selectedClient,
                    )}
                  </h2>
                  <p>
                    Ajoutez les lignes. Le backend recalcule les totaux après
                    chaque ajout.
                  </p>
                </div>

                <span className={`status ${isEmitted ? "success" : "warning"}`}>
                  {isEmitted ? "Émise" : "Brouillon"}
                </span>
              </div>

              {!isEmitted && (
                <form className="line-form" onSubmit={handleAddLine}>
                  <div className="line-form-grid">
                    <label>
                      Désignation
                      <input
                        type="text"
                        value={designation}
                        placeholder="Ex : Développement module facture"
                        onChange={(event) => setDesignation(event.target.value)}
                      />
                    </label>

                    <label>
                      Qté
                      <input
                        type="number"
                        step="0.01"
                        min="0"
                        value={quantite}
                        onChange={(event) => setQuantite(event.target.value)}
                      />
                    </label>

                    <label>
                      PU HT
                      <input
                        type="number"
                        step="0.01"
                        min="0"
                        value={prixUnitaireHt}
                        placeholder="1200"
                        onChange={(event) =>
                          setPrixUnitaireHt(event.target.value)
                        }
                      />
                    </label>

                    <label>
                      TVA %
                      <input
                        type="number"
                        step="0.01"
                        min="0"
                        value={tauxTva}
                        onChange={(event) => setTauxTva(event.target.value)}
                      />
                    </label>
                  </div>

                  {error && <div className="state-card error">{error}</div>}

                  <button
                    type="submit"
                    className="primary-btn create-draft-btn"
                    disabled={isAddingLine}
                  >
                    <CirclePlus size={16} />
                    {isAddingLine ? "Ajout..." : "Ajouter la ligne"}
                  </button>
                </form>
              )}

              {isEmitted && (
                <div className="state-card">
                  Facture émise : les lignes ne sont plus modifiables.
                </div>
              )}

              {lignes.length === 0 && (
                <div className="state-card">
                  Aucune ligne pour le moment. Ajoutez une première prestation.
                </div>
              )}

              {lignes.length > 0 && (
                <div className="invoice-lines-table">
                  <div className="invoice-lines-header">
                    <span>Désignation</span>
                    <span>Qté</span>
                    <span>PU HT</span>
                    <span>TVA</span>
                    <span>Total TTC</span>
                  </div>

                  {lignes.map((ligne) => (
                    <div className="invoice-lines-row" key={ligne.id}>
                      <strong>{ligne.designation}</strong>
                      <span>{formatQuantity(ligne.quantite)}</span>
                      <span>
                        {formatCurrency(toNumber(ligne.prix_unitaire_ht))}
                      </span>
                      <span>{formatPercent(ligne.taux_tva)}</span>
                      <strong>
                        {formatCurrency(toNumber(ligne.total_ttc))}
                      </strong>
                    </div>
                  ))}
                </div>
              )}

              <div className="invoice-totals-card">
                <div>
                  <span>Total HT</span>
                  <strong>
                    {formatCurrency(toNumber(createdFacture.total_ht))}
                  </strong>
                </div>

                <div>
                  <span>TVA</span>
                  <strong>
                    {formatCurrency(toNumber(createdFacture.total_tva))}
                  </strong>
                </div>

                <div className="total-ttc-row">
                  <span>Total TTC</span>
                  <strong>
                    {formatCurrency(toNumber(createdFacture.total_ttc))}
                  </strong>
                </div>
              </div>

              <div className="invoice-actions-row">
                {!isEmitted && (
                  <>
                    <button
                      type="button"
                      className="secondary-btn"
                      disabled={isCheckingConformite || lignes.length === 0}
                      onClick={handleCheckConformite}
                    >
                      <ShieldCheck size={16} />
                      {isCheckingConformite
                        ? "Vérification..."
                        : "Vérifier conformité"}
                    </button>

                    <button
                      type="button"
                      className="primary-btn"
                      disabled={!canEmit || isEmitting}
                      onClick={handleEmitFacture}
                    >
                      <Send size={16} />
                      {isEmitting ? "Émission..." : "Émettre"}
                    </button>
                  </>
                )}

                {isEmitted && (
                  <>
                    <button
                      type="button"
                      className="secondary-btn"
                      onClick={handleOpenPdf}
                    >
                      <ExternalLink size={16} />
                      Ouvrir PDF
                    </button>

                    <button
                      type="button"
                      className="secondary-btn"
                      onClick={handleOpenXml}
                    >
                      <ExternalLink size={16} />
                      Ouvrir XML
                    </button>
                  </>
                )}
              </div>

              {!isEmitted && conformite && (
                <div
                  className={`conformite-result-card ${
                    conformite.conforme ? "success" : "error"
                  }`}
                >
                  <strong>
                    {conformite.conforme
                      ? "Facture conforme"
                      : "Facture non conforme"}
                  </strong>

                  {getConformiteErrors(conformite).length > 0 && (
                    <ul>
                      {getConformiteErrors(conformite).map((message, index) => (
                        <li key={`${message}-${index}`}>{message}</li>
                      ))}
                    </ul>
                  )}

                  {getConformiteWarnings(conformite).length > 0 && (
                    <ul>
                      {getConformiteWarnings(conformite).map(
                        (message, index) => (
                          <li key={`${message}-${index}`}>{message}</li>
                        ),
                      )}
                    </ul>
                  )}

                  {conformite.conforme &&
                    getConformiteErrors(conformite).length === 0 &&
                    getConformiteWarnings(conformite).length === 0 && (
                      <p>Aucune erreur bloquante détectée.</p>
                    )}
                </div>
              )}

              {isEmitted && (
                <div className="conformite-result-card success">
                  <strong>Facture émise avec succès</strong>
                  <p>
                    Le PDF/A-3 Factur-X et le XML embarqué sont disponibles.
                  </p>
                </div>
              )}
            </div>
          )}
        </section>

        <aside className="quick-create-aside">
          <div className="compliance-panel">
            <div className="compliance-panel-title">
              <CheckCircle2 size={20} />
              <h2>Pré-contrôle</h2>
            </div>

            <ul>
              <li>Client actif uniquement</li>
              <li>Échéance préparée</li>
              <li>Conditions de paiement ajoutées</li>
              <li>Prix unitaire positif obligatoire</li>
              <li>Totaux recalculés par Rails</li>
              <li>Émission bloquée sans conformité OK</li>
            </ul>
          </div>

          {createdFacture && (
            <div className="created-draft-card">
              <span className="success-dot">✓</span>

              <div>
                <strong>{isEmitted ? "Facture émise" : "Brouillon prêt"}</strong>
                <p>
                  {createdFacture.numero ?? "Brouillon"} · {lignes.length} ligne
                  {lignes.length > 1 ? "s" : ""}
                </p>
                <small>ID : {createdFacture.id.slice(0, 8)}</small>
              </div>
            </div>
          )}
        </aside>
      </div>
    </section>
  );
}

function buildDefaultDueDate() {
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

function formatClientRouting(client: Client) {
  if (client.identifiant_routage_pa) {
    return `Routage PA ${client.identifiant_routage_pa}`;
  }

  return "Routage PA non renseigné";
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat("fr-FR", {
    day: "2-digit",
    month: "long",
    year: "numeric",
  }).format(new Date(value));
}

function getCreatedFactureClientName(
  facture: Facture,
  fallbackClient: Client | null,
) {
  return (
    facture.client?.raison_sociale ??
    fallbackClient?.raison_sociale ??
    `Client ${facture.client_id.slice(0, 8)}`
  );
}

function parseDecimal(value: string) {
  const parsed = Number(value.replace(",", "."));

  return Number.isFinite(parsed) ? parsed : 0;
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

function formatPercent(value: string | number | null | undefined) {
  return `${toNumber(value)} %`;
}

function formatQuantity(value: string | number | null | undefined) {
  return new Intl.NumberFormat("fr-FR", {
    maximumFractionDigits: 2,
  }).format(toNumber(value));
}

function getConformiteErrors(result: ConformiteResult) {
  return result.erreurs ?? [];
}

function getConformiteWarnings(result: ConformiteResult) {
  return result.avertissements ?? result.warnings ?? [];
}
