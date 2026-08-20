import { Compass, Menu } from "lucide-react";
import { useState } from "react";
import type { ReactNode } from "react";
import { Link } from "react-router-dom";
import { SerenoLogo } from "../branding/SerenoLogo";
import { MobileNavDrawer } from "./MobileNavDrawer";

const PUBLIC_NAV_ITEMS = [
  { href: "#accueil", label: "Accueil" },
  { href: "#comment-ca-marche", label: "Comment ça marche" },
  { href: "#vos-donnees", label: "Vos données" },
  { href: "#pourquoi-sereno", label: "Pourquoi Sereno" },
];

const MOBILE_NAV_DRAWER_ID = "public-mobile-nav-drawer";

type PublicShellProps = {
  children: ReactNode;
};

// R1.1 (prompt_claude_code_entree_publique_r1_1_correction_humaine.txt §6.1-
// 6.3) — même frontière PUBLIQUE dédiée qu'en R1 (OPTION A, jamais un mode
// anonyme d'AppShell/Sidebar/Topbar), mêmes primitifs génériques réutilisés
// tels quels (.sereno-app/.sereno-frame/.main/.topbar/.hamburger-btn/
// .sr-only/.topbar-brand/.logo-title/.primary-btn/.secondary-btn,
// SerenoLogo, MobileNavDrawer). Ce qui change ce sprint (§3 diagnostic
// R1.1) :
// - sous-titre de marque raccourci (ne casse plus sur 3 lignes) ;
// - intitulés de navigation orientés bénéfice (Comment ça marche/Vos
//   données/Pourquoi Sereno) plutôt que des noms de section techniques ;
// - un bloc de réassurance compact sous la nav (jamais un calendrier/faux
//   abonnement) pour que la sidebar cesse de paraître vide ;
// - un accès "Se connecter" discret en pied de sidebar (jamais un profil
//   fictif) ;
// - topbar allégée : UNE seule action ("Connexion"), le bouton "Découvrir
//   Sereno" disparaît (même action déjà présente dans le hero, §6.3 :
//   "ne pas répéter les mêmes CTA dans trois endroits").
export function PublicShell({ children }: PublicShellProps) {
  const [isMobileNavOpen, setIsMobileNavOpen] = useState(false);

  function closeMobileNav() {
    setIsMobileNavOpen(false);
  }

  return (
    <div className="sereno-app">
      <div className="sereno-frame">
        <aside className="public-sidebar" aria-label="Navigation publique">
          <div className="topbar-brand">
            <SerenoLogo size={38} />

            <div className="logo-title">
              <strong>Sereno</strong>
              <span>Facturation électronique</span>
            </div>
          </div>

          <nav className="public-sidebar__nav" aria-label="Sections de la page">
            {PUBLIC_NAV_ITEMS.map((item) => (
              <a key={item.href} href={item.href} className="public-sidebar__link">
                {item.label}
              </a>
            ))}
          </nav>

          <div className="public-sidebar__reassurance">
            <span className="public-sidebar__reassurance-icon">
              <Compass size={16} aria-hidden="true" />
            </span>
            <div>
              <strong>Conçu pour vous guider</strong>
              <p>Des contrôles clairs avant l&rsquo;envoi, sans jargon inutile.</p>
            </div>
          </div>

          <Link to="/login" className="public-sidebar__login">
            Se connecter
          </Link>
        </aside>

        <header className="topbar public-topbar">
          <button
            type="button"
            className="hamburger-btn"
            onClick={() => setIsMobileNavOpen(true)}
            aria-label="Ouvrir le menu"
            aria-expanded={isMobileNavOpen}
            aria-controls={`${MOBILE_NAV_DRAWER_ID}-title`}
          >
            <Menu size={20} aria-hidden="true" />
          </button>

          <span className="public-topbar__context">Sereno · Facturation électronique</span>

          <Link to="/login" className="primary-btn public-topbar__login">
            Connexion
          </Link>
        </header>

        <main className="main">{children}</main>

        <MobileNavDrawer
          id={MOBILE_NAV_DRAWER_ID}
          isOpen={isMobileNavOpen}
          onClose={closeMobileNav}
          label="Navigation publique"
        >
          <div className="public-drawer">
            <div className="topbar-brand">
              <SerenoLogo size={38} />

              <div className="logo-title">
                <strong>Sereno</strong>
                <span>Facturation électronique</span>
              </div>
            </div>

            <nav className="public-sidebar__nav" aria-label="Sections de la page">
              {PUBLIC_NAV_ITEMS.map((item) => (
                <a
                  key={item.href}
                  href={item.href}
                  className="public-sidebar__link"
                  onClick={closeMobileNav}
                >
                  {item.label}
                </a>
              ))}
            </nav>

            <Link to="/login" className="primary-btn public-drawer__login" onClick={closeMobileNav}>
              Se connecter
            </Link>
          </div>
        </MobileNavDrawer>
      </div>
    </div>
  );
}
