import { Download, FileSpreadsheet } from "lucide-react";
import { useEffect, useState } from "react";
import { getFecApercu, getFecExportUrl } from "../api/exportsApi";
import { getApiErrorMessage } from "../api/http";

function debutParDefaut() {
  const maintenant = new Date();

  return `${maintenant.getFullYear()}-01-01`;
}

function finParDefaut() {
  return new Date().toISOString().slice(0, 10);
}

// Export FEC (MVP) — panneau MINIMAL : deux dates + un bouton. L'étiquette
// d'honnêteté (§6 execution_export_fec_mvp.txt) est chargée dès que la
// plage de dates est valide et affichée de façon PROMINENTE AVANT tout
// téléchargement — jamais dans le fichier .txt lui-même.
export function FecExportPanel() {
  const [debut, setDebut] = useState(debutParDefaut());
  const [fin, setFin] = useState(finParDefaut());
  const [etiquette, setEtiquette] = useState<string | null>(null);
  const [nomFichier, setNomFichier] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (!debut || !fin) {
      return;
    }

    let ignore = false;

    void getFecApercu(debut, fin)
      .then((apercu) => {
        if (ignore) {
          return;
        }

        setEtiquette(apercu.etiquette);
        setNomFichier(apercu.nom_fichier);
        setError(null);
      })
      .catch((apiError) => {
        if (ignore) {
          return;
        }

        setEtiquette(null);
        setNomFichier(null);
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
  }, [debut, fin]);

  function handleDownload() {
    if (!debut || !fin || !etiquette || error) {
      return;
    }

    window.open(getFecExportUrl(debut, fin), "_blank", "noopener,noreferrer");
  }

  return (
    <section className="kpi-card" aria-labelledby="fec-export-title">
      <div className="parametres-card-header">
        <FileSpreadsheet size={20} aria-hidden="true" />
      </div>

      <strong id="fec-export-title">Export comptable (FEC)</strong>
      <span>
        Écritures reconstituées à partir de vos factures, avoirs et
        paiements — au format attendu par l'administration fiscale.
      </span>

      <form
        className="line-form"
        onSubmit={(event) => {
          event.preventDefault();
          handleDownload();
        }}
      >
        <div className="line-form-grid">
          <label>
            Du
            <input
              type="date"
              value={debut}
              onChange={(event) => {
                setIsLoading(true);
                setDebut(event.target.value);
              }}
            />
          </label>

          <label>
            Au
            <input
              type="date"
              value={fin}
              onChange={(event) => {
                setIsLoading(true);
                setFin(event.target.value);
              }}
            />
          </label>
        </div>

        {etiquette && (
          <p className="hint-text" role="note">
            {etiquette}
          </p>
        )}

        {error && <p className="invoice-transmission-section__error">{error}</p>}

        <button
          type="submit"
          className="primary-btn create-draft-btn"
          disabled={isLoading || !etiquette || Boolean(error)}
        >
          <Download size={16} />
          {isLoading ? "Préparation..." : `Télécharger le FEC${nomFichier ? ` (${nomFichier})` : ""}`}
        </button>
      </form>
    </section>
  );
}
