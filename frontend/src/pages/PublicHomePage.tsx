import {
  AlertCircle,
  ArrowRight,
  Building2,
  CheckCircle2,
  Clock3,
  Eye,
  FileCheck2,
  FilePlus2,
  FileText,
  Lock,
  Send,
  ShieldCheck,
} from "lucide-react";
import { Fragment } from "react";
import { Link, Navigate } from "react-router-dom";
import { PublicShell } from "../components/layout/PublicShell";
import { useAuth } from "../context/useAuth";

// R1.1 (§8.1) — bande "Comment ça marche" : un seul chemin lu en un regard,
// jamais 4 cartes clonées (diagnostic R1 point 4). Verbes à l'impératif,
// tels que rédigés par le prompt.
const PARCOURS_ETAPES = [
  { icon: FilePlus2, title: "Créez", text: "Préparez votre facture avec les informations utiles." },
  { icon: ShieldCheck, title: "Vérifiez", text: "Repérez ce qui manque avant l'envoi." },
  { icon: Send, title: "Envoyez", text: "Transmettez-la en un geste." },
  { icon: Eye, title: "Suivez", text: "Voyez où elle en est, jusqu'au paiement." },
];

// R1.1 (§6.4) — ligne de confiance compacte sous les actions du hero :
// preuves courtes, jamais des badges marketing.
const HERO_TRUST_ITEMS = [
  { icon: CheckCircle2, label: "Contrôles avant envoi" },
  { icon: FileCheck2, label: "Format Factur-X" },
  { icon: ShieldCheck, label: "Espace protégé" },
];

// R1.1 (§8.3) — "Vos données", fusion des anciennes répétitions en une
// scène de confiance compacte, 3 preuves maximum (diagnostic R1 point 4).
const VOS_DONNEES_PREUVES = [
  { icon: Building2, text: "Un espace séparé pour chaque entreprise" },
  { icon: Lock, text: "Votre mot de passe n'est jamais conservé tel quel" },
  { icon: ShieldCheck, text: "Des contrôles utiles avant l'envoi" },
];

// R1.1 (prompt_claude_code_entree_publique_r1_1_correction_humaine.txt) —
// correction artistique du premier jet R1 (toujours techniquement GREEN,
// désormais AMBER visuel en attente de captures, cf. rapport R1.1). §5 :
// l'ARCHITECTURE reste inchangée — même garde d'authentification (patron
// LoginPage), même absence totale d'appel API métier, même refus d'un CTA
// d'inscription actif (le backend n'existe pas). Ce qui change ici est
// exclusivement la composition visuelle et le contenu éditorial : une
// grande scène produit remplace le petit panneau à 3 lignes, la grille de
// documentation à 4 cartes répétées disparaît au profit de 3 moments
// visuels distincts (§8).
export function PublicHomePage() {
  const { isAuthenticated } = useAuth();

  if (isAuthenticated) {
    return <Navigate to="/app/dashboard" replace />;
  }

  return (
    <PublicShell>
      <section className="landing-hero" id="accueil">
        <div className="landing-hero__content">
          <p className="landing-hero__eyebrow">Votre facturation, sans le brouillard</p>
          <h1>Facturer devrait être simple.</h1>
          <p className="landing-hero__intro">
            Sereno vous guide du premier devis au paiement, sans vous laisser
            seul face aux règles.
          </p>

          <div className="landing-hero__actions">
            <a href="#comment-ca-marche" className="primary-btn">
              Voir comment ça marche
            </a>
            <Link to="/login" className="secondary-btn">
              Se connecter
            </Link>
          </div>

          <ul className="landing-hero__trust">
            {HERO_TRUST_ITEMS.map((item) => (
              <li key={item.label}>
                <item.icon size={14} aria-hidden="true" />
                {item.label}
              </li>
            ))}
          </ul>
        </div>

        {/* R1.1 §7 — grande scène produit : un parcours humain (créer,
            vérifier, envoyer, suivre), une facture EXPLICITEMENT générique
            ("Facture de démonstration"), aucun chiffre, client, montant ou
            taux de conformité inventé. Purement décorative : jamais
            interactive, jamais d'appel API. */}
        <div className="landing-scene" aria-hidden="true">
          <div className="landing-scene__card">
            <div className="landing-scene__header">
              <span className="landing-scene__kicker">Votre facture avance</span>
              <span className="landing-scene__doc">
                <FileText size={14} aria-hidden="true" />
                Facture de démonstration
              </span>
            </div>

            <div className="landing-scene__steps">
              <div className="landing-scene__step is-done">
                <span className="landing-scene__step-icon">
                  <FilePlus2 size={16} aria-hidden="true" />
                </span>
                <span>Créer</span>
              </div>
              <ArrowRight className="landing-scene__step-arrow" size={14} aria-hidden="true" />
              <div className="landing-scene__step is-current">
                <span className="landing-scene__step-icon">
                  <ShieldCheck size={16} aria-hidden="true" />
                </span>
                <span>Vérifier</span>
              </div>
              <ArrowRight className="landing-scene__step-arrow" size={14} aria-hidden="true" />
              <div className="landing-scene__step">
                <span className="landing-scene__step-icon">
                  <Send size={16} aria-hidden="true" />
                </span>
                <span>Envoyer</span>
              </div>
              <ArrowRight className="landing-scene__step-arrow" size={14} aria-hidden="true" />
              <div className="landing-scene__step">
                <span className="landing-scene__step-icon">
                  <Eye size={16} aria-hidden="true" />
                </span>
                <span>Suivre</span>
              </div>
            </div>

            <div className="landing-scene__status">
              <span className="landing-scene__status-icon">
                <Clock3 size={18} aria-hidden="true" />
              </span>
              <div>
                <strong>Prête à vérifier</strong>
                <span>Vous gardez la main avant l&rsquo;envoi.</span>
              </div>
            </div>

            <ul className="landing-scene__checks">
              <li className="is-done">
                <CheckCircle2 size={15} aria-hidden="true" />
                Informations complètes
              </li>
              <li className="is-done">
                <CheckCircle2 size={15} aria-hidden="true" />
                Format prêt
              </li>
              <li className="is-pending">
                <AlertCircle size={15} aria-hidden="true" />
                Échéance renseignée
              </li>
            </ul>
          </div>

          <div className="landing-scene__float landing-scene__float--a">
            <FileCheck2 size={13} aria-hidden="true" />
            Factur-X
          </div>

          <div className="landing-scene__float landing-scene__float--b">
            <CheckCircle2 size={18} aria-hidden="true" />
          </div>
        </div>
      </section>

      <section className="landing-section" id="comment-ca-marche">
        <div className="landing-section__heading">
          <p className="landing-section__eyebrow">Comment ça marche</p>
          <h2>Un chemin clair, du premier geste à l&rsquo;archivage.</h2>
        </div>

        <div className="landing-path">
          {PARCOURS_ETAPES.map((etape, index) => (
            <Fragment key={etape.title}>
              <div className="landing-path__step">
                <span className="landing-path__icon">
                  <etape.icon size={20} aria-hidden="true" />
                </span>
                <strong>{etape.title}</strong>
                <p>{etape.text}</p>
              </div>

              {index < PARCOURS_ETAPES.length - 1 && (
                <ArrowRight className="landing-path__arrow" size={18} aria-hidden="true" />
              )}
            </Fragment>
          ))}
        </div>
      </section>

      <section className="landing-section" id="pourquoi-sereno">
        <div className="landing-section__heading">
          <p className="landing-section__eyebrow">Pourquoi Sereno</p>
          <h2>Moins de doutes, plus de temps.</h2>
        </div>

        <div className="landing-benefits">
          <article className="landing-benefits__major">
            <span className="landing-card__icon">
              <Eye size={22} aria-hidden="true" />
            </span>
            <h3>Moins de doutes</h3>
            <p>Sereno signale ce qui mérite votre attention.</p>
          </article>

          <div className="landing-benefits__minor">
            <article className="landing-card landing-card--compact">
              <span className="landing-card__icon">
                <CheckCircle2 size={18} aria-hidden="true" />
              </span>
              <h3 className="landing-card__title">Moins d&rsquo;oublis</h3>
              <p className="landing-card__text">Les étapes importantes restent visibles.</p>
            </article>

            <article className="landing-card landing-card--compact">
              <span className="landing-card__icon">
                <Clock3 size={18} aria-hidden="true" />
              </span>
              <h3 className="landing-card__title">Plus de temps pour votre métier</h3>
              <p className="landing-card__text">
                Vos documents restent organisés au même endroit.
              </p>
            </article>
          </div>
        </div>
      </section>

      <section className="landing-section" id="vos-donnees">
        <div className="landing-trust">
          <div className="landing-trust__intro">
            <p className="landing-section__eyebrow">Vos données</p>
            <h2>Sérieux avec vos données. Clair avec vous.</h2>
            <p className="landing-section__intro">
              Sereno vous aide à préparer vos documents et à repérer les
              informations manquantes. Vous gardez la décision finale.
            </p>
          </div>

          <ul className="landing-trust__list">
            {VOS_DONNEES_PREUVES.map((preuve) => (
              <li key={preuve.text}>
                <span className="landing-card__icon">
                  <preuve.icon size={18} aria-hidden="true" />
                </span>
                {preuve.text}
              </li>
            ))}
          </ul>
        </div>
      </section>

      <section className="landing-cta-footer">
        <h2>Prêt à retrouver une facturation plus claire ?</h2>
        <Link to="/login" className="primary-btn">
          Se connecter
        </Link>
      </section>
    </PublicShell>
  );
}
