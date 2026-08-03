import axios from "axios";
import { ArrowLeft, CirclePlus, ClipboardList, Send, Trash2 } from "lucide-react";
import { useEffect, useState, type FormEventHandler } from "react";
import { Link, useParams } from "react-router-dom";
import {
  accepterDevis,
  convertirDevis,
  envoyerDevis,
  getDevis,
  refuserDevis,
} from "../api/devisApi";
import { listEvenementsDevis } from "../api/evenementsDevisApi";
import { getApiErrorMessage } from "../api/http";
import { createLigneDevis, deleteLigneDevis } from "../api/lignesDevisApi";
import { ConfirmModal } from "../components/ConfirmModal";
import { DevisEventHistory } from "../components/DevisEventHistory";
import type { Devis, DevisStatut } from "../types/devis";
import type { EvenementDevis } from "../types/evenementDevis";
import type { LigneDevis } from "../types/ligneDevis";

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

// Les erreurs métier du backend (422) portent le message affichable dans
// `details`, jamais dans `error` (qui reste un libellé générique d'action —
// cf. Api::V1::DevisController). getApiErrorMessage (http.ts, partagé avec
// facture/avoir) ne lit que `error` : ce helper local préfère `details`,
// sans toucher au comportement partagé des autres pages.
function getDevisActionErrorMessage(apiError: unknown): string {
  if (axios.isAxiosError(apiError)) {
    const data = apiError.response?.data as { details?: string[] } | undefined;

    if (data?.details && data.details.length > 0) {
      return data.details.join(" ");
    }
  }

  return getApiErrorMessage(apiError);
}

function toNumber(value: string | number | null | undefined) {
  const parsed = Number(value ?? 0);

  return Number.isFinite(parsed) ? parsed : 0;
}

function parseDecimal(value: string) {
  const parsed = Number(value.replace(",", "."));

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

export function DevisDetailPage() {
  const { id } = useParams<{ id: string }>();

  const [devis, setDevis] = useState<Devis | null>(null);
  const [isLoading, setIsLoading] = useState(Boolean(id));
  const [error, setError] = useState<string | null>(null);

  const [events, setEvents] = useState<EvenementDevis[]>([]);
  const [isLoadingEvents, setIsLoadingEvents] = useState(Boolean(id));
  const [eventsError, setEventsError] = useState<string | null>(null);

  const [designation, setDesignation] = useState("");
  const [quantite, setQuantite] = useState("1");
  const [prixUnitaireHt, setPrixUnitaireHt] = useState("");
  const [tauxTva, setTauxTva] = useState("20");
  const [isAddingLine, setIsAddingLine] = useState(false);
  const [lineError, setLineError] = useState<string | null>(null);
  const [deletingLineId, setDeletingLineId] = useState<string | null>(null);
  const [lineToDelete, setLineToDelete] = useState<LigneDevis | null>(null);

  const [isSending, setIsSending] = useState(false);
  const [sendConfirmOpen, setSendConfirmOpen] = useState(false);
  const [isAccepting, setIsAccepting] = useState(false);
  const [acceptConfirmOpen, setAcceptConfirmOpen] = useState(false);
  const [isRefusing, setIsRefusing] = useState(false);
  const [refuseConfirmOpen, setRefuseConfirmOpen] = useState(false);
  const [isConverting, setIsConverting] = useState(false);
  const [convertConfirmOpen, setConvertConfirmOpen] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  // Après succès, on NAVIGUE vers la facture créée (FactureBlueprint) — le
  // devis n'a pas besoin d'être resynchronisé localement, on quitte la page.
  const [convertedFactureId, setConvertedFactureId] = useState<string | null>(
    null,
  );

  const lignes = devis?.lignes_devis ?? [];
  const isDraft = devis?.statut === "brouillon";
  const isEnvoye = devis?.statut === "envoye";
  const isAccepte = devis?.statut === "accepte";

  useEffect(() => {
    if (!id) {
      return;
    }

    let ignore = false;

    void getDevis(id)
      .then((data) => {
        if (!ignore) {
          setDevis(data);
          setError(null);
        }
      })
      .catch((apiError) => {
        if (!ignore) {
          setError(getApiErrorMessage(apiError));
        }
      })
      .finally(() => {
        if (!ignore) {
          setIsLoading(false);
        }
      });

    return () => {
      ignore = true;
    };
  }, [id]);

  useEffect(() => {
    if (!id) {
      return;
    }

    let ignore = false;

    void listEvenementsDevis(id)
      .then((data) => {
        if (!ignore) {
          setEvents(data);
          setEventsError(null);
        }
      })
      .catch((apiError) => {
        if (!ignore) {
          setEventsError(getApiErrorMessage(apiError));
        }
      })
      .finally(() => {
        if (!ignore) {
          setIsLoadingEvents(false);
        }
      });

    return () => {
      ignore = true;
    };
  }, [id]);

  const handleAddLine: FormEventHandler<HTMLFormElement> = async (event) => {
    event.preventDefault();

    if (!devis) {
      setLineError("Devis introuvable.");
      return;
    }

    if (!isDraft) {
      setLineError("Ce devis a été envoyé. Il ne peut plus être modifié.");
      return;
    }

    const parsedQuantite = parseDecimal(quantite);
    const parsedPrixUnitaireHt = parseDecimal(prixUnitaireHt);
    const parsedTauxTva = parseDecimal(tauxTva);

    if (designation.trim().length < 2) {
      setLineError("La désignation doit contenir au moins 2 caractères.");
      return;
    }

    if (parsedQuantite <= 0) {
      setLineError("La quantité doit être supérieure à 0.");
      return;
    }

    if (parsedPrixUnitaireHt <= 0) {
      setLineError("Le prix unitaire HT doit être supérieur à 0.");
      return;
    }

    if (parsedTauxTva < 0) {
      setLineError("Le taux de TVA doit être positif ou nul.");
      return;
    }

    setLineError(null);
    setIsAddingLine(true);

    try {
      const updatedDevis = await createLigneDevis(devis.id, {
        designation: designation.trim(),
        quantite: parsedQuantite,
        prix_unitaire_ht: parsedPrixUnitaireHt,
        taux_tva: parsedTauxTva,
        position: lignes.length + 1,
      });

      setDevis(updatedDevis);
      setDesignation("");
      setQuantite("1");
      setPrixUnitaireHt("");
      setTauxTva("20");
    } catch (apiError) {
      setLineError(getApiErrorMessage(apiError));
    } finally {
      setIsAddingLine(false);
    }
  };

  function handleAskDeleteLine(ligne: LigneDevis) {
    if (!devis || !isDraft) {
      setLineError("Seules les lignes d’un brouillon peuvent être supprimées.");
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
    if (!devis || !lineToDelete) {
      return;
    }

    setDeletingLineId(lineToDelete.id);
    setLineError(null);

    try {
      const updatedDevis = await deleteLigneDevis(devis.id, lineToDelete.id);

      setDevis(updatedDevis);
      setLineToDelete(null);
    } catch (apiError) {
      setLineError(getApiErrorMessage(apiError));
      setLineToDelete(null);
    } finally {
      setDeletingLineId(null);
    }
  }

  async function handleConfirmEnvoyer() {
    if (!devis) {
      return;
    }

    setActionError(null);
    setIsSending(true);

    try {
      const updated = await envoyerDevis(devis.id);
      setDevis(updated);
    } catch (apiError) {
      setActionError(getDevisActionErrorMessage(apiError));
    } finally {
      setIsSending(false);
      setSendConfirmOpen(false);
    }
  }

  async function handleConfirmAccepter() {
    if (!devis) {
      return;
    }

    setActionError(null);
    setIsAccepting(true);

    try {
      const updated = await accepterDevis(devis.id);
      setDevis(updated);
    } catch (apiError) {
      setActionError(getDevisActionErrorMessage(apiError));
    } finally {
      setIsAccepting(false);
      setAcceptConfirmOpen(false);
    }
  }

  async function handleConfirmRefuser() {
    if (!devis) {
      return;
    }

    setActionError(null);
    setIsRefusing(true);

    try {
      const updated = await refuserDevis(devis.id);
      setDevis(updated);
    } catch (apiError) {
      setActionError(getDevisActionErrorMessage(apiError));
    } finally {
      setIsRefusing(false);
      setRefuseConfirmOpen(false);
    }
  }

  async function handleConfirmConvertir() {
    if (!devis) {
      return;
    }

    setActionError(null);
    setIsConverting(true);

    try {
      const facture = await convertirDevis(devis.id);
      setConvertedFactureId(facture.id);
    } catch (apiError) {
      setActionError(getDevisActionErrorMessage(apiError));
      setConvertConfirmOpen(false);
    } finally {
      setIsConverting(false);
    }
  }

  return (
    <section className="new-invoice-page">
      <div className="page-heading">
        <div>
          <span className="page-kicker">Détail devis</span>
          <h1>Détail du devis</h1>
          <p>Consultez le devis, gérez ses lignes et pilotez son cycle commercial.</p>
        </div>

        <Link to="/app/devis" className="secondary-btn">
          <ArrowLeft size={16} />
          Retour liste
        </Link>
      </div>

      {isLoading && <div className="state-card">Chargement du devis...</div>}

      {error && <div className="state-card error">{error}</div>}

      {!isLoading && !devis && !error && (
        <div className="state-card">Devis introuvable.</div>
      )}

      {convertedFactureId && (
        <div className="conformite-result-card success">
          <strong>Devis converti avec succès</strong>
          <p>
            La facture a été créée, numérotée et émise à partir des lignes de
            ce devis.
          </p>
          <div className="invoice-actions-row">
            <Link
              to={`/app/factures/${convertedFactureId}`}
              className="primary-btn"
            >
              Voir la facture
            </Link>
          </div>
        </div>
      )}

      {!isLoading && devis && (
        <div className="invoice-builder-card">
          <div className="invoice-builder-header">
            <div>
              <span className="page-kicker">{devis.numero ?? "Brouillon enregistré"}</span>
              <h2>{devis.client?.raison_sociale ?? "Client"}</h2>
              {devis.objet && <p>{devis.objet}</p>}
            </div>

            <span className={`status ${STATUS_VARIANTS[devis.statut]}`}>
              {STATUS_LABELS[devis.statut]}
            </span>
          </div>

          <div className="avoir-identity-strip">
            <span className="badge-devis">
              <ClipboardList size={14} /> Devis
            </span>

            <span>
              Validité : {formatDate(devis.date_validite)}
              {devis.expire && (
                <span className="devis-accent-text"> · Expiré</span>
              )}
            </span>

            {devis.converti && devis.facture_generee && (
              <Link
                to={`/app/factures/${devis.facture_generee.id}`}
                className="devis-accent-text"
              >
                Converti en facture {devis.facture_generee.numero}
              </Link>
            )}
          </div>

          <div className="invoice-totals-card">
            <div>
              <span>Total HT</span>
              <strong>{formatCurrency(toNumber(devis.total_ht))}</strong>
            </div>

            <div>
              <span>TVA</span>
              <strong>{formatCurrency(toNumber(devis.total_tva))}</strong>
            </div>

            <div className="total-ttc-row">
              <span>Total TTC</span>
              <strong>{formatCurrency(toNumber(devis.total_ttc))}</strong>
            </div>
          </div>
        </div>
      )}

      {!isLoading && devis && (
        <div className="invoice-builder-card">
          {isDraft && (
            <form className="line-form" onSubmit={handleAddLine}>
              <div className="line-form-grid">
                <label>
                  Désignation
                  <input
                    type="text"
                    value={designation}
                    placeholder="Ex : Développement module devis"
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
                    onChange={(event) => setPrixUnitaireHt(event.target.value)}
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
              Ce devis a été envoyé : ses lignes ne sont plus modifiables.
            </div>
          )}

          {lineError && <div className="state-card error">{lineError}</div>}

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
        </div>
      )}

      {!isLoading && devis && (
        <div className="invoice-actions-row">
          {isDraft && (
            <button
              type="button"
              className="devis-btn"
              disabled={isSending}
              onClick={() => setSendConfirmOpen(true)}
            >
              <Send size={16} />
              {isSending ? "Envoi..." : "Envoyer le devis"}
            </button>
          )}

          {isEnvoye && (
            <>
              <button
                type="button"
                className="primary-btn"
                disabled={isAccepting}
                onClick={() => setAcceptConfirmOpen(true)}
              >
                {isAccepting ? "Enregistrement..." : "Enregistrer l’accord du client"}
              </button>

              <button
                type="button"
                className="secondary-btn"
                disabled={isRefusing}
                onClick={() => setRefuseConfirmOpen(true)}
              >
                {isRefusing ? "Enregistrement..." : "Enregistrer le refus du client"}
              </button>
            </>
          )}

          {isAccepte && !devis?.converti && (
            <button
              type="button"
              className="primary-btn"
              disabled={isConverting}
              onClick={() => setConvertConfirmOpen(true)}
            >
              {isConverting ? "Conversion..." : "Convertir en facture"}
            </button>
          )}
        </div>
      )}

      {actionError && <div className="state-card error">{actionError}</div>}

      {!isLoading && devis && (
        <DevisEventHistory
          events={events}
          isLoading={isLoadingEvents}
          error={eventsError}
        />
      )}

      <ConfirmModal
        open={Boolean(lineToDelete)}
        title="Supprimer cette ligne ?"
        message={
          lineToDelete
            ? `La ligne "${lineToDelete.designation}" sera supprimée du brouillon. Les totaux du devis seront recalculés.`
            : ""
        }
        confirmLabel={deletingLineId ? "Suppression..." : "Supprimer la ligne"}
        destructive
        isLoading={Boolean(deletingLineId)}
        onCancel={handleCancelDeleteLine}
        onConfirm={handleConfirmDeleteLine}
      />

      <ConfirmModal
        open={sendConfirmOpen}
        title="Envoyer définitivement ce devis ?"
        message="Une fois envoyé, son contenu et ses lignes ne pourront plus être modifiés. Vous pourrez ensuite enregistrer la réponse reçue de votre client."
        cancelLabel="Annuler"
        confirmLabel={isSending ? "Envoi en cours…" : "Envoyer le devis"}
        isLoading={isSending}
        onCancel={() => setSendConfirmOpen(false)}
        onConfirm={() => {
          void handleConfirmEnvoyer();
        }}
      />

      <ConfirmModal
        open={acceptConfirmOpen}
        title="Enregistrer l’accord du client ?"
        message="Vous confirmez avoir reçu l’accord de votre client par un autre moyen (téléphone, email, signature). Sereno ne contacte jamais le client lui-même."
        cancelLabel="Annuler"
        confirmLabel={isAccepting ? "Enregistrement en cours…" : "Enregistrer l’accord"}
        isLoading={isAccepting}
        onCancel={() => setAcceptConfirmOpen(false)}
        onConfirm={() => {
          void handleConfirmAccepter();
        }}
      />

      <ConfirmModal
        open={refuseConfirmOpen}
        title="Enregistrer le refus du client ?"
        message="Vous confirmez que votre client a refusé cette proposition."
        cancelLabel="Annuler"
        confirmLabel={isRefusing ? "Enregistrement en cours…" : "Enregistrer le refus"}
        isLoading={isRefusing}
        onCancel={() => setRefuseConfirmOpen(false)}
        onConfirm={() => {
          void handleConfirmRefuser();
        }}
      />

      <ConfirmModal
        open={convertConfirmOpen}
        title="Convertir ce devis en facture définitive ?"
        message="Sereno créera une facture à partir des lignes du devis, recalculera les montants, vérifiera sa conformité, lui attribuera un numéro définitif et l’émettra. Cette facture sera définitive et le devis restera archivé comme trace, non modifiable."
        cancelLabel="Annuler"
        confirmLabel={isConverting ? "Conversion en cours…" : "Convertir en facture"}
        isLoading={isConverting}
        onCancel={() => setConvertConfirmOpen(false)}
        onConfirm={() => {
          void handleConfirmConvertir();
        }}
      />
    </section>
  );
}
