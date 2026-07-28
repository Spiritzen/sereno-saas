import { AlertTriangle, ArrowLeft, ExternalLink, Receipt, Send } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { createAvoir, emettreAvoir, getAvoirPdfUrl, listAvoirs, sommeAvoirsDejaEmis } from "../api/avoirsApi";
import { createLigneAvoir } from "../api/lignesAvoirApi";
import { getFacture } from "../api/facturesApi";
import { getApiErrorMessage } from "../api/http";
import { listLignesFacture } from "../api/lignesFactureApi";
import { ConfirmModal } from "../components/ConfirmModal";
import type { Avoir } from "../types/avoir";
import type { Facture } from "../types/facture";
import type { LigneFacture } from "../types/ligneFacture";

// CORRECTION v2 (post-sélection stricte) : le cocher/décocher de lignes
// entières (v1) était trop rigide — impossible de créditer 200 € sur une
// facture d'une seule ligne à 600 €. On passe à un MONTANT À CRÉDITER
// éditable par ligne, saisi en TTC (ce que l'utilisateur pense : « je rends
// X € au client »), plafonné au TTC facturé de cette ligne. La désignation,
// la quantité, le PU HT et le taux de TVA restent figés (repris de la
// facture, jamais inventés) ; seul ce montant est éditable.
const TOLERANCE_CENTIME = 0.01;

function toNumber(value: string | number | null | undefined) {
  const parsed = Number(value ?? 0);

  return Number.isFinite(parsed) ? parsed : 0;
}

// Arrondi 2 décimales via la notation exponentielle, pour éviter les dérives
// flottantes de type 1.005 -> 1.00 (cf. backend BigDecimal ROUND_HALF_UP,
// qu'on cherche à reproduire fidèlement pour ne jamais s'écarter du total
// que le backend recalculera après création des lignes).
function round2(value: number) {
  return Number(`${Math.round(Number(`${value}e2`))}e-2`);
}

function clamp(value: number, min: number, max: number) {
  return Math.min(Math.max(value, min), max);
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

function formatQuantity(value: string | number | null | undefined) {
  return new Intl.NumberFormat("fr-FR", {
    maximumFractionDigits: 2,
  }).format(toNumber(value));
}

function formatPercent(value: string | number | null | undefined) {
  return `${toNumber(value)} %`;
}

type LigneCredit = {
  ligne: LigneFacture;
  taux: number;
  ttcFacture: number;
  ttcCredite: number;
  htCredite: number;
  tvaInfo: number;
  resteFacture: number;
};

// Reproduit EXACTEMENT la formule backend (Avoir#recalculer_totaux!, appelée
// après chaque création de ligne_avoir) : HT = TTC_crédité / (1 + taux/100),
// TVA informée = TTC_crédité × taux / (100 + taux) (même dénominateur, pour
// des arrondis cohérents entre les deux). Le plafond [0, ttcFacture] rend le
// dépassement de LA LIGNE structurellement impossible.
function calculerLigneCredit(ligne: LigneFacture, rawValue: string | undefined): LigneCredit {
  const ttcFacture = toNumber(ligne.total_ttc);
  const taux = toNumber(ligne.taux_tva);
  const ttcCredite = clamp(toNumber(rawValue), 0, ttcFacture);
  const htCredite = round2((ttcCredite * 100) / (100 + taux));
  const tvaInfo = round2((ttcCredite * taux) / (100 + taux));
  const resteFacture = round2(ttcFacture - ttcCredite);

  return { ligne, taux, ttcFacture, ttcCredite, htCredite, tvaInfo, resteFacture };
}

export function NewCreditNotePage() {
  const { id: factureId } = useParams<{ id: string }>();
  const navigate = useNavigate();

  const [facture, setFacture] = useState<Facture | null>(null);
  const [avoirsExistants, setAvoirsExistants] = useState<Avoir[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [lignesFacture, setLignesFacture] = useState<LigneFacture[]>([]);
  // Montant à créditer par ligne, saisi en TTC, tenu en état BRUT (string)
  // pour ne pas gêner la frappe (ex. "12." en cours de saisie) ; le
  // plafonnement/l'arrondi réels se font dans calculerLigneCredit, jamais
  // sur la valeur affichée pendant la frappe (seulement au blur, cf. plus
  // bas), sauf dépassement du plafond qui est corrigé immédiatement.
  const [creditsTtc, setCreditsTtc] = useState<Record<string, string>>({});
  const [motif, setMotif] = useState("");

  const [isCreating, setIsCreating] = useState(false);
  const [createError, setCreateError] = useState<string | null>(null);
  const [avoirCree, setAvoirCree] = useState<Avoir | null>(null);

  const [isEmitConfirmOpen, setIsEmitConfirmOpen] = useState(false);
  const [isEmitting, setIsEmitting] = useState(false);
  const [emitError, setEmitError] = useState<string | null>(null);

  useEffect(() => {
    if (!factureId) {
      return;
    }

    let ignore = false;

    void Promise.all([
      getFacture(factureId),
      listLignesFacture(factureId),
      listAvoirs(factureId),
    ])
      .then(([factureData, lignesData, avoirsData]) => {
        if (ignore) {
          return;
        }

        setFacture(factureData);
        setAvoirsExistants(avoirsData);
        setLignesFacture(lignesData);
        // Avoir total par défaut : chaque ligne est pré-remplie au montant
        // TTC facturé ; l'utilisateur RÉDUIT pour un partiel, ou met 0 pour
        // ne pas créditer cette ligne.
        setCreditsTtc(
          Object.fromEntries(
            lignesData.map((ligne) => [ligne.id, String(round2(toNumber(ligne.total_ttc)))]),
          ),
        );
      })
      .catch((apiError) => {
        if (!ignore) {
          setLoadError(getApiErrorMessage(apiError));
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
  }, [factureId]);

  const lignesCredit = useMemo(
    () => lignesFacture.map((ligne) => calculerLigneCredit(ligne, creditsTtc[ligne.id])),
    [lignesFacture, creditsTtc],
  );

  const lignesRetenues = useMemo(
    () => lignesCredit.filter((calc) => calc.ttcCredite > 0),
    [lignesCredit],
  );

  // Totaux = somme des HT crédités (chacun déjà arrondi à 2 décimales), puis
  // TVA = arrondi UNIQUE de la somme des produits HT × taux / 100 — dans cet
  // ORDRE (somme d'abord, arrondi ensuite), pour reproduire fidèlement
  // Avoir#recalculer_totaux! côté backend (`sum("total_ht * taux_tva / 100")`
  // en SQL, arrondi une seule fois à l'écriture en base). Arrondir la TVA
  // ligne à ligne AVANT de sommer pourrait diverger du backend de 0,01 € sur
  // certaines combinaisons multi-lignes/multi-taux.
  const totalHt = round2(lignesRetenues.reduce((somme, calc) => somme + calc.htCredite, 0));
  const totalTva = round2(
    lignesRetenues.reduce((somme, calc) => somme + (calc.htCredite * calc.taux) / 100, 0),
  );
  const totalTtc = round2(totalHt + totalTva);

  const factureTotalTtc = toNumber(facture?.total_ttc);
  const dejaEmisAutresAvoirs = useMemo(
    () => sommeAvoirsDejaEmis(avoirsExistants),
    [avoirsExistants],
  );
  // Garde-fou CUMULÉ (dernier recours) : le plafond PAR LIGNE rend déjà le
  // dépassement de LA FACTURE structurellement impossible en une seule
  // création. Ce calcul cumulé ne protège donc que contre le cas résiduel :
  // re-créditer une facture déjà couverte par un avoir émis précédemment.
  // Approche (b) retenue plutôt que (a) : ligne_avoir n'a aucune colonne de
  // traçabilité vers ligne_facture (pas de ligne_facture_id), donc réduire le
  // plafond LIGNE PAR LIGNE du montant déjà crédité sur CETTE ligne
  // précisément n'est pas faisable sans évolution backend (hors périmètre,
  // correction frontend uniquement). Le plafond global (b) reste robuste :
  // il empêche tout sur-crédit, tous avoirs confondus.
  const resteCreditable = factureTotalTtc - dejaEmisAutresAvoirs - totalTtc;
  const depassement = resteCreditable < -TOLERANCE_CENTIME;

  const peutValider =
    Boolean(facture) &&
    !avoirCree &&
    lignesRetenues.length > 0 &&
    motif.trim().length > 0 &&
    !depassement;

  function handleChangeCredit(ligneId: string, value: string, maxTtc: number) {
    const parsed = toNumber(value);

    if (parsed > maxTtc) {
      setCreditsTtc((precedent) => ({ ...precedent, [ligneId]: String(round2(maxTtc)) }));
      return;
    }

    if (parsed < 0) {
      setCreditsTtc((precedent) => ({ ...precedent, [ligneId]: "0" }));
      return;
    }

    setCreditsTtc((precedent) => ({ ...precedent, [ligneId]: value }));
  }

  function handleBlurCredit(ligneId: string, maxTtc: number) {
    setCreditsTtc((precedent) => ({
      ...precedent,
      [ligneId]: String(round2(clamp(toNumber(precedent[ligneId]), 0, maxTtc))),
    }));
  }

  async function handleCreerAvoir() {
    if (!factureId || !peutValider) {
      return;
    }

    setCreateError(null);
    setIsCreating(true);

    try {
      const avoir = await createAvoir({ facture_id: factureId, motif: motif.trim() });

      let dernierAvoir = avoir;

      for (const [index, calc] of lignesRetenues.entries()) {
        dernierAvoir = await createLigneAvoir(avoir.id, {
          designation: calc.ligne.designation,
          quantite: 1,
          prix_unitaire_ht: calc.htCredite,
          taux_tva: calc.taux,
          position: index + 1,
        });
      }

      setAvoirCree(dernierAvoir);
    } catch (apiError) {
      setCreateError(getApiErrorMessage(apiError));
    } finally {
      setIsCreating(false);
    }
  }

  async function handleEmettre() {
    if (!avoirCree) {
      return;
    }

    setEmitError(null);
    setIsEmitting(true);

    try {
      const avoirEmis = await emettreAvoir(avoirCree.id);
      navigate(`/app/avoirs/${avoirEmis.id}`);
    } catch (apiError) {
      setEmitError(getApiErrorMessage(apiError));
    } finally {
      setIsEmitting(false);
      setIsEmitConfirmOpen(false);
    }
  }

  function handleOpenPdf() {
    if (!avoirCree?.pdf_url) {
      return;
    }

    window.open(getAvoirPdfUrl(avoirCree.id), "_blank", "noopener,noreferrer");
  }

  return (
    <section className="new-invoice-page">
      <div className="page-heading">
        <div>
          <span className="page-kicker">Nouvel avoir</span>
          <h1>Créer un avoir</h1>
          <p>
            Chaque ligne est pré-remplie au montant facturé (avoir total).
            Réduisez le montant « à créditer » pour un avoir partiel, ou
            mettez-le à 0 pour exclure une ligne : un avoir reprend les
            lignes facturées, il n’en invente jamais.
          </p>
        </div>

        <span className="badge-avoir">
          <Receipt size={14} /> Avoir
        </span>
      </div>

      {isLoading && <div className="state-card">Chargement de la facture...</div>}

      {loadError && <div className="state-card error">{loadError}</div>}

      {!isLoading && facture && facture.statut === "brouillon" && (
        <div className="state-card error">
          Cette facture est encore en brouillon : un avoir ne peut être créé
          que sur une facture émise.
        </div>
      )}

      {!isLoading && facture && facture.statut !== "brouillon" && !avoirCree && (
        <div className="invoice-builder-card">
          <div className="invoice-builder-header">
            <div>
              <span className="page-kicker">Facture {facture.numero}</span>
              <h2>Avoir sur {facture.client?.raison_sociale ?? "ce client"}</h2>
            </div>
          </div>

          <label className="search-field" style={{ display: "block", marginBottom: 16 }}>
            Motif de l’avoir (obligatoire)
            <input
              type="text"
              value={motif}
              placeholder="Ex : erreur de tarification sur la ligne 2"
              onChange={(event) => setMotif(event.target.value)}
            />
          </label>

          {lignesFacture.length === 0 && (
            <div className="state-card">
              Cette facture n’a aucune ligne : impossible de créer un avoir.
            </div>
          )}

          {lignesFacture.length > 0 && (
            <div className="invoice-lines-table avoir-credit-table">
              <div className="invoice-lines-header">
                <span>Désignation</span>
                <span>Qté</span>
                <span>PU HT</span>
                <span>TVA</span>
                <span>Facturé (TTC)</span>
                <span>À créditer (TTC)</span>
                <span>TVA créditée</span>
                <span>Reste facturé</span>
              </div>

              {lignesCredit.map((calc) => (
                <div className="invoice-lines-row" key={calc.ligne.id}>
                  <strong>{calc.ligne.designation}</strong>
                  <span>{formatQuantity(calc.ligne.quantite)}</span>
                  <span>{formatCurrency(toNumber(calc.ligne.prix_unitaire_ht))}</span>
                  <span>{formatPercent(calc.ligne.taux_tva)}</span>
                  <strong>{formatCurrency(calc.ttcFacture)}</strong>

                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    max={calc.ttcFacture}
                    className="credit-amount-input"
                    value={creditsTtc[calc.ligne.id] ?? "0"}
                    onChange={(event) =>
                      handleChangeCredit(calc.ligne.id, event.target.value, calc.ttcFacture)
                    }
                    onBlur={() => handleBlurCredit(calc.ligne.id, calc.ttcFacture)}
                    aria-label={`Montant à créditer pour la ligne ${calc.ligne.designation}`}
                  />

                  <span className="info-muted">{formatCurrency(calc.tvaInfo)}</span>
                  <span className="info-muted">{formatCurrency(calc.resteFacture)}</span>
                </div>
              ))}
            </div>
          )}

          {lignesFacture.length > 0 && lignesRetenues.length === 0 && (
            <p className="hint-text">Aucun montant à créditer pour l’instant.</p>
          )}

          <div className="invoice-totals-card">
            <div>
              <span>Total HT crédité</span>
              <strong>{formatCurrency(totalHt)}</strong>
            </div>

            <div>
              <span>TVA créditée</span>
              <strong>{formatCurrency(totalTva)}</strong>
            </div>

            <div className="total-ttc-row">
              <span>Total TTC de l’avoir</span>
              <strong>{formatCurrency(totalTtc)}</strong>
            </div>
          </div>

          <div
            className={`conformite-result-card ${depassement ? "error" : "success"}`}
          >
            <strong>
              {depassement ? (
                <>
                  <AlertTriangle size={16} aria-hidden="true" /> Sur-crédit :
                  cette facture est déjà couverte par un avoir émis
                </>
              ) : (
                "Montant créditable respecté"
              )}
            </strong>
            <p>
              Vous créditez {formatCurrency(totalTtc)} sur une facture de{" "}
              {formatCurrency(factureTotalTtc)} TTC
              {dejaEmisAutresAvoirs > 0 &&
                ` (dont ${formatCurrency(dejaEmisAutresAvoirs)} déjà crédités par d’autres avoirs)`}
              {" — "}
              {depassement
                ? `dépassement de ${formatCurrency(Math.abs(resteCreditable))} : réduisez les montants à créditer.`
                : `reste ${formatCurrency(resteCreditable)} créditables après cet avoir.`}
            </p>
          </div>

          {createError && <div className="state-card error">{createError}</div>}

          <div className="invoice-actions-row">
            <button
              type="button"
              className="avoir-btn"
              disabled={!peutValider || isCreating}
              onClick={() => {
                void handleCreerAvoir();
              }}
            >
              <Receipt size={16} />
              {isCreating ? "Création..." : "Créer l’avoir"}
            </button>
          </div>
        </div>
      )}

      {avoirCree && (
        <div className="invoice-builder-card">
          <div className="invoice-builder-header">
            <div>
              <span className="page-kicker">Brouillon enregistré</span>
              <h2>Avoir sur {facture?.client?.raison_sociale ?? "ce client"}</h2>
              <p>Motif : {avoirCree.motif}</p>
            </div>

            <span className="status warning">Brouillon</span>
          </div>

          <div className="invoice-totals-card">
            <div>
              <span>Total HT</span>
              <strong>{formatCurrency(toNumber(avoirCree.total_ht))}</strong>
            </div>

            <div>
              <span>TVA</span>
              <strong>{formatCurrency(toNumber(avoirCree.total_tva))}</strong>
            </div>

            <div className="total-ttc-row">
              <span>Total TTC</span>
              <strong>{formatCurrency(toNumber(avoirCree.total_ttc))}</strong>
            </div>
          </div>

          {emitError && <div className="state-card error">{emitError}</div>}

          <div className="invoice-actions-row">
            <button
              type="button"
              className="avoir-btn"
              disabled={isEmitting}
              onClick={() => setIsEmitConfirmOpen(true)}
            >
              <Send size={16} />
              {isEmitting ? "Émission..." : "Émettre l’avoir"}
            </button>

            {avoirCree.pdf_url && (
              <button type="button" className="secondary-btn" onClick={handleOpenPdf}>
                <ExternalLink size={16} />
                Ouvrir PDF
              </button>
            )}
          </div>
        </div>
      )}

      <div className="page-heading">
        <Link to={`/app/factures/${factureId ?? ""}`} className="secondary-btn">
          <ArrowLeft size={16} />
          Retour à la facture
        </Link>
      </div>

      <ConfirmModal
        open={isEmitConfirmOpen}
        title="Émettre définitivement cet avoir ?"
        message={
          avoirCree
            ? `Vous êtes sur le point d’émettre un avoir de ${formatCurrency(
                toNumber(avoirCree.total_ttc),
              )} sur la facture ${facture?.numero ?? ""}. Cette action est IRRÉVERSIBLE.`
            : ""
        }
        cancelLabel="Annuler"
        confirmLabel={isEmitting ? "Émission en cours…" : "Émettre définitivement"}
        isLoading={isEmitting}
        onCancel={() => setIsEmitConfirmOpen(false)}
        onConfirm={() => {
          void handleEmettre();
        }}
      />
    </section>
  );
}
