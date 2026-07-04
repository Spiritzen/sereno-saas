import { Eye, Send, ShieldCheck } from "lucide-react";

export function NewInvoicePage() {
  return (
    <>
      <section className="hero-row">
        <div>
          <p className="eyebrow">FAC-2026-015 · Brouillon enregistré</p>
          <h1>Nouvelle facture</h1>
        </div>

        <span className="pa-pill">Plus qu’un clic</span>
      </section>

      <section className="new-invoice-layout">
        <div className="form-card">
          <div className="client-box">
            <div className="client-head">
              <div className="client-identity">
                <div className="client-avatar">SN</div>
                <div>
                  <strong>Studio Novaris</strong>
                  <p className="eyebrow">SIRET 823 491 002 00017 · TVA FR42823491002</p>
                </div>
              </div>

              <button className="secondary-btn">Modifier</button>
            </div>

            <p className="eyebrow">14 rue des Tanneurs, 67000 Strasbourg</p>
            <p style={{ color: "var(--color-success)", marginBottom: 0 }}>
              Mentions récupérées · destinataire identifié sur la PA
            </p>
          </div>

          <div className="table">
            <div className="table-row table-head">
              <span>Désignation</span>
              <span>Qté</span>
              <span>PU HT</span>
              <span>TVA</span>
              <span>Total</span>
            </div>

            <div className="table-row">
              <strong>Refonte identité visuelle</strong>
              <span>1</span>
              <span>2 000 €</span>
              <span>20 %</span>
              <strong>2 000 €</strong>
            </div>

            <div className="table-row">
              <strong>Pack 3 déclinaisons logo</strong>
              <span>1</span>
              <span>400 €</span>
              <span>20 %</span>
              <strong>400 €</strong>
            </div>

            <div className="table-row">
              <button className="secondary-btn">+ Ajouter une ligne</button>
            </div>
          </div>

          <div className="total-box">
            <div className="total-line">
              <span>Total HT</span>
              <strong>2 400 €</strong>
            </div>
            <div className="total-line">
              <span>TVA (20 %)</span>
              <strong>480 €</strong>
            </div>
            <div className="total-line final">
              <span>Total TTC</span>
              <strong>2 880 €</strong>
            </div>
          </div>

          <div className="invoice-actions">
            <button className="secondary-btn">
              <Eye size={16} /> Aperçu
            </button>
            <button className="primary-btn">
              <Send size={16} /> Émettre & transmettre via la PA
            </button>
          </div>
        </div>

        <aside className="conformity-panel">
          <h2>
            <ShieldCheck size={20} /> Tout est en règle
          </h2>

          <div className="check-list">
            <span>✓ Numéro séquentiel</span>
            <span>✓ Mentions 2026</span>
            <span>✓ Format Factur-X</span>
            <span>✓ Destinataire PA</span>
            <span>✓ TVA cohérente</span>
          </div>
        </aside>
      </section>
    </>
  );
}