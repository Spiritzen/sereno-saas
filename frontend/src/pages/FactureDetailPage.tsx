import {
  ArrowLeft,
  CirclePlus,
  ExternalLink,
  FileText,
  Send,
  ShieldCheck,
  Trash2,
} from "lucide-react";
import { useEffect, useState, type FormEventHandler } from "react";
import { Link, useParams } from "react-router-dom";
import {
  emettreFacture,
  getConformiteFacture,
  getFacture,
  getFacturePdfUrl,
  getFactureXmlUrl,
} from "../api/facturesApi";
import { getApiErrorMessage } from "../api/http";
import {
  createLigneFacture,
  deleteLigneFacture,
  listLignesFacture,
} from "../api/lignesFactureApi";
import { ConfirmModal } from "../components/ConfirmModal";
import { InvoiceLifecycleTimeline } from "../components/InvoiceLifecycleTimeline";
import type { ConformiteResult } from "../types/conformite";
import type { Facture } from "../types/facture";
import type { LigneFacture } from "../types/ligneFacture";

export function FactureDetailPage() {
  const { id } = useParams<{ id: string }>();

  const [facture, setFacture] = useState<Facture | null>(null);
  const [lignes, setLignes] = useState<LigneFacture[]>([]);
  const [conformite, setConformite] = useState<ConformiteResult | null>(null);

  const [designation, setDesignation] = useState("");
  const [quantite, setQuantite] = useState("1");
  const [prixUnitaireHt, setPrixUnitaireHt] = useState("");
  const [tauxTva, setTauxTva] = useState("20");

  const [isLoading, setIsLoading] = useState(Boolean(id));
  const [isAddingLine, setIsAddingLine] = useState(false);
  const [deletingLineId, setDeletingLineId] = useState<string | null>(null);
  const [lineToDelete, setLineToDelete] = useState<LigneFacture | null>(null);
  const [isCheckingConformite, setIsCheckingConformite] = useState(false);
  const [isEmitting, setIsEmitting] = useState(false);
  const [isEmitConfirmOpen, setIsEmitConfirmOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const isDraft = facture?.statut === "brouillon";

  // B2 : on n'affiche les liens PDF/XML que si le backend confirme leur présence.
  const hasPdf = Boolean(facture?.pdf_url);
  const hasXml = Boolean(facture?.xml_url);

  const canEmit =
    Boolean(facture) &&
    isDraft &&
    lignes.length > 0 &&
    conformite?.conforme === true;

  useEffect(() => {
    if (!id) {
      return;
    }

    let ignore = false;

    void Promise.all([getFacture(id), listLignesFacture(id)])
      .then(([factureData, lignesData]) => {
        if (ignore) {
          return;
        }

        setFacture(factureData);
        setLignes(lignesData);
        setConformite(null);
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
  }, [id]);

  const handleAddLine: FormEventHandler<HTMLFormElement> = async (event) => {
    event.preventDefault();

    if (!facture) {
      setError("Facture introuvable.");
      return;
    }

    if (!isDraft) {
      setError("Cette facture est émise. Elle ne peut plus être modifiée.");
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
      const updatedFacture = await createLigneFacture(facture.id, {
        designation: designation.trim(),
        quantite: parsedQuantite,
        prix_unitaire_ht: parsedPrixUnitaireHt,
        taux_tva: parsedTauxTva,
        position: lignes.length + 1,
      });

      const updatedLignes = await listLignesFacture(facture.id);

      setFacture(updatedFacture);
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

  function handleAskDeleteLine(ligne: LigneFacture) {
    if (!facture || !isDraft) {
      setError("Seules les lignes d’un brouillon peuvent être supprimées.");
      return;
    }

    setLineToDelete(ligne);
  }

  function handleCancelDeleteLine() {
    if (deletingLineId) {
      return;
    }

    setLineToDelete(null);
  }

  async function handleConfirmDeleteLine() {
    if (!facture || !lineToDelete) {
      return;
    }

    if (!isDraft) {
      setError("Seules les lignes d’un brouillon peuvent être supprimées.");
      setLineToDelete(null);
      return;
    }

    setDeletingLineId(lineToDelete.id);
    setError(null);

    try {
      const updatedFacture = await deleteLigneFacture(lineToDelete.id);
      const updatedLignes = await listLignesFacture(facture.id);

      setFacture(updatedFacture);
      setLignes(updatedLignes);
      setConformite(null);
      setLineToDelete(null);
    } catch (apiError) {
      setError(getApiErrorMessage(apiError));
      setLineToDelete(null);
    } finally {
      setDeletingLineId(null);
    }
  }

  async function handleCheckConformite() {
    if (!facture) {
      setError("Facture introuvable.");
      return;
    }

    if (lignes.length === 0) {
      setError("Ajoutez au moins une ligne avant de vérifier la conformité.");
      return;
    }

    setError(null);
    setIsCheckingConformite(true);

    try {
      const result = await getConformiteFacture(facture.id);
      setConformite(result);
    } catch (apiError) {
      setError(getApiErrorMessage(apiError));
    } finally {
      setIsCheckingConformite(false);
    }
  }

  async function handleEmitFacture() {
    if (!facture) {
      setError("Facture introuvable.");
      return;
    }

    if (!conformite?.conforme) {
      setError("Vérifiez la conformité avant d’émettre la facture.");
      return;
    }

    setError(null);
    setIsEmitting(true);

    try {
      const emittedFacture = await emettreFacture(facture.id);
      const updatedLignes = await listLignesFacture(facture.id);

      setFacture(emittedFacture);
      setLignes(updatedLignes);
      setConformite(null);
    } catch (apiError) {
      setError(getApiErrorMessage(apiError));
    } finally {
      setIsEmitting(false);
    }
  }

  const handleConfirmEmitFacture = async () => {
    await handleEmitFacture();
    setIsEmitConfirmOpen(false);
  };

  function handleOpenPdf() {
    if (!facture || !hasPdf) {
      return;
    }

    window.open(getFacturePdfUrl(facture.id), "_blank", "noopener,noreferrer");
  }

  function handleOpenXml() {
    if (!facture || !hasXml) {
      return;
    }

    window.open(getFactureXmlUrl(facture.id), "_blank", "noopener,noreferrer");
  }

  return (
    <section className="new-invoice-page">
      <div className="page-heading">
        <div>
          <span className="page-kicker">Détail facture</span>
          <h1>{facture?.numero ?? "Brouillon"}</h1>
          <p>
            Consultez le document, modifiez les brouillons et accédez aux
            fichiers PDF/XML après émission.
          </p>
        </div>

        <Link to="/app/factures" className="secondary-btn">
          <ArrowLeft size={16} />
          Retour liste
        </Link>
      </div>

      {isLoading && (
        <div className="state-card">Chargement de la facture...</div>
      )}

      {error && <div className="state-card error">{error}</div>}

      {!isLoading && !facture && !error && (
        <div className="state-card">Facture introuvable.</div>
      )}

      {!isLoading && facture && (
        <InvoiceLifecycleTimeline
          status={facture.statut}
          createdAt={facture.created_at}
          emittedAt={facture.emise_at}
          invoiceNumber={facture.numero}
        />
      )}

      {!isLoading && facture && (
        <div className="invoice-builder-card">
          <div className="invoice-builder-header">
            <div>
              <span className="page-kicker">
                {facture.numero ?? "Brouillon enregistré"}
              </span>
              <h2>{facture.client?.raison_sociale ?? "Client non chargé"}</h2>
              <p>
                {isDraft
                  ? "Ce brouillon peut encore être modifié avant émission."
                  : "Cette facture est émise : elle est consultable, mais non modifiable."}
              </p>
            </div>

            <span className={`status ${isDraft ? "warning" : "success"}`}>
              {isDraft ? "Brouillon" : "Émise"}
            </span>
          </div>

          <div className="draft-preview-card">
            <div className="document-icon">
              <FileText size={18} />
            </div>

            <div>
              <strong>{facture.numero ?? "Brouillon sans numéro"}</strong>
              <span>
                Échéance : {formatDate(facture.date_echeance)} · Format :{" "}
                {formatFactureFormat(facture.format)}
              </span>
            </div>
          </div>

          {isDraft && (
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

          {!isDraft && (
            <div className="state-card">
              Facture émise : les lignes ne sont plus modifiables. Toute
              correction passera plus tard par un avoir.
            </div>
          )}

          {lignes.length === 0 && (
            <div className="state-card">
              Aucune ligne pour le moment. Ajoutez une première prestation.
            </div>
          )}

          {lignes.length > 0 && (
            <div className="invoice-lines-table detail-lines-table">
              <div className="invoice-lines-header">
                <span>Désignation</span>
                <span>Qté</span>
                <span>PU HT</span>
                <span>TVA</span>
                <span>Total TTC</span>
                {isDraft && <span>Action</span>}
              </div>

              {lignes.map((ligne) => (
                <div className="invoice-lines-row" key={ligne.id}>
                  <strong>{ligne.designation}</strong>
                  <span>{formatQuantity(ligne.quantite)}</span>
                  <span>{formatCurrency(toNumber(ligne.prix_unitaire_ht))}</span>
                  <span>{formatPercent(ligne.taux_tva)}</span>
                  <strong>{formatCurrency(toNumber(ligne.total_ttc))}</strong>

                  {isDraft && (
                    <button
                      type="button"
                      className="table-action-btn danger"
                      disabled={deletingLineId === ligne.id}
                      onClick={() => handleAskDeleteLine(ligne)}
                    >
                      <Trash2 size={14} />
                      {deletingLineId === ligne.id
                        ? "Suppression..."
                        : "Supprimer"}
                    </button>
                  )}
                </div>
              ))}
            </div>
          )}

          <div className="invoice-totals-card">
            <div>
              <span>Total HT</span>
              <strong>{formatCurrency(toNumber(facture.total_ht))}</strong>
            </div>

            <div>
              <span>TVA</span>
              <strong>{formatCurrency(toNumber(facture.total_tva))}</strong>
            </div>

            <div className="total-ttc-row">
              <span>Total TTC</span>
              <strong>{formatCurrency(toNumber(facture.total_ttc))}</strong>
            </div>
          </div>

          <div className="invoice-actions-row">
            {isDraft && (
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
                  onClick={() => setIsEmitConfirmOpen(true)}
                >
                  <Send size={16} />
                  {isEmitting ? "Émission..." : "Émettre"}
                </button>
              </>
            )}

            {!isDraft && (
              <>
                {hasPdf && (
                  <button
                    type="button"
                    className="secondary-btn"
                    onClick={handleOpenPdf}
                  >
                    <ExternalLink size={16} />
                    Ouvrir PDF
                  </button>
                )}

                {hasXml && (
                  <button
                    type="button"
                    className="secondary-btn"
                    onClick={handleOpenXml}
                  >
                    <ExternalLink size={16} />
                    Ouvrir XML
                  </button>
                )}

                {!hasPdf && !hasXml && (
                  <div className="state-card">
                    Les fichiers PDF/XML ne sont pas encore disponibles pour
                    cette facture.
                  </div>
                )}
              </>
            )}
          </div>

          {isDraft && conformite && (
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
                  {getConformiteWarnings(conformite).map((message, index) => (
                    <li key={`${message}-${index}`}>{message}</li>
                  ))}
                </ul>
              )}

              {conformite.conforme &&
                getConformiteErrors(conformite).length === 0 &&
                getConformiteWarnings(conformite).length === 0 && (
                  <p>Aucune erreur bloquante détectée.</p>
                )}
            </div>
          )}
        </div>
      )}

      <ConfirmModal
        open={Boolean(lineToDelete)}
        title="Supprimer cette ligne ?"
        message={
          lineToDelete
            ? `La ligne "${lineToDelete.designation}" sera supprimée du brouillon. Les totaux de la facture seront recalculés.`
            : ""
        }
        confirmLabel={deletingLineId ? "Suppression..." : "Supprimer la ligne"}
        destructive
        isLoading={Boolean(deletingLineId)}
        onCancel={handleCancelDeleteLine}
        onConfirm={handleConfirmDeleteLine}
      />

      <ConfirmModal
        open={isEmitConfirmOpen}
        title="Émettre définitivement cette facture ?"
        message="Une fois émise, cette facture sera numérotée et ne pourra plus être modifiée ni supprimée. Vérifiez les informations avant de continuer."
        cancelLabel="Annuler"
        confirmLabel={isEmitting ? "Émission en cours…" : "Émettre définitivement"}
        isLoading={isEmitting}
        onCancel={() => setIsEmitConfirmOpen(false)}
        onConfirm={() => {
          void handleConfirmEmitFacture();
        }}
      />
    </section>
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

function formatDate(value: string | null | undefined) {
  if (!value) {
    return "Non renseignée";
  }

  return new Intl.DateTimeFormat("fr-FR", {
    day: "2-digit",
    month: "long",
    year: "numeric",
  }).format(new Date(value));
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

function getConformiteErrors(result: ConformiteResult) {
  return result.erreurs ?? [];
}

function getConformiteWarnings(result: ConformiteResult) {
  return result.avertissements ?? result.warnings ?? [];
}