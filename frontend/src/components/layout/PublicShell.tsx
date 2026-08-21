import { Compass, Menu } from "lucide-react";
import { useState } from "react";
import type { ReactNode } from "react";
import { Link, useLocation } from "react-router-dom";
import { AuthModal } from "../auth/AuthModal";
import { useAuth } from "../../context/useAuth";
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
// SerenoLogo, MobileNavDrawer).
//
// R3 (prompt_claude_code_inscription_owner_frontend_r3.txt §10/§11) —
// « Connexion »/« Se connecter » n'ouvrent plus /login mais une modale
// accessible (AuthModal, réutilisant ModalShell tel quel) SANS changer
// l'URL ; /login reste une route publique fonctionnelle de secours et de
// deep-link, jamais retirée. Un accès « Créer mon espace » (route dédiée
// /inscription, JAMAIS une modale — trop de champs) est ajouté en sidebar/
// tiroir mobile, sans devenir une liste d'actions concurrentes (une seule
// paire CTA principal/secondaire, comme le hero).
//
// Cette modale est POSSÉDÉE localement par PublicShell, pour ses propres
// déclencheurs (sidebar/topbar/tiroir). PublicHomePage, qui INSTANCIE
// PublicShell (donc son ANCÊTRE dans l'arbre, jamais un descendant), ne peut
// structurellement pas consommer un contexte fourni PAR PublicShell — un
// essai initial via un contexte partagé a été abandonné pour cette raison
// exacte (React ne remonte jamais le contexte vers un ancêtre). Le bouton
// secondaire du hero de PublicHomePage possède donc sa PROPRE instance
// indépendante d'AuthModal (même composant, même comportement, état séparé)
// plutôt qu'une fausse mécanique de partage impossible à faire fonctionner.
//
// Nav par ancres rendue route-aware : sur "/" (page qui porte réellement les
// sections #accueil/#comment-ca-marche/...), les liens restent de simples
// ancres `<a href="#...">` (comportement R1.1 inchangé, testé tel quel).
// Sur toute AUTRE page publique utilisant ce shell (ex. /inscription, qui ne
// porte pas ces sections), ils deviennent des <Link to="/#..."> qui
// ramènent réellement à la landing plutôt que des ancres mortes.
//
// R3 (§11) — décision confirmée (Sébastien) : PublicHomePage et
// InscriptionPage conservent TOUTES DEUX leur garde de redirection complète
// existante (`if (isAuthenticated) return <Navigate to="/app/dashboard" />`,
// patron R1/LoginPage) — un OWNER déjà connecté ne voit donc JAMAIS ce
// composant s'afficher, dans l'usage actuel. Le remplacement de CTA
// ci-dessous est néanmoins implémenté ICI, dans le shell partagé, pour que
// tout futur consommateur de PublicShell qui omettrait sa propre garde reste
// honnête — jamais un « Se connecter »/« Créer mon espace » présenté à un
// utilisateur déjà authentifié. Prouvé par un test dédié qui monte
// PublicShell directement (cf. PublicShell.test.tsx), pas par
// PublicHomePage.test.tsx (qui ne peut structurellement pas l'exercer).
export function PublicShell({ children }: PublicShellProps) {
  const [isMobileNavOpen, setIsMobileNavOpen] = useState(false);
  const [isAuthModalOpen, setIsAuthModalOpen] = useState(false);
  const location = useLocation();
  const { isAuthenticated } = useAuth();
  const isHomePage = location.pathname === "/";

  function closeMobileNav() {
    setIsMobileNavOpen(false);
  }

  function openLoginModal() {
    setIsAuthModalOpen(true);
  }

  function closeLoginModal() {
    setIsAuthModalOpen(false);
  }

  function openLoginModalFromDrawer() {
    closeMobileNav();
    openLoginModal();
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
            {PUBLIC_NAV_ITEMS.map((item) =>
              isHomePage ? (
                <a key={item.href} href={item.href} className="public-sidebar__link">
                  {item.label}
                </a>
              ) : (
                <Link key={item.href} to={`/${item.href}`} className="public-sidebar__link">
                  {item.label}
                </Link>
              ),
            )}
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

          {isAuthenticated ? (
            <Link to="/app/dashboard" className="public-sidebar__cta">
              Ouvrir mon cockpit
            </Link>
          ) : (
            <>
              <Link to="/inscription" className="public-sidebar__cta">
                Créer mon espace
              </Link>

              <button type="button" className="public-sidebar__login" onClick={openLoginModal}>
                Se connecter
              </button>
            </>
          )}
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

          {isAuthenticated ? (
            <Link to="/app/dashboard" className="primary-btn public-topbar__login">
              Ouvrir mon cockpit
            </Link>
          ) : (
            <button
              type="button"
              className="primary-btn public-topbar__login"
              onClick={openLoginModal}
            >
              Connexion
            </button>
          )}
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
              {PUBLIC_NAV_ITEMS.map((item) =>
                isHomePage ? (
                  <a
                    key={item.href}
                    href={item.href}
                    className="public-sidebar__link"
                    onClick={closeMobileNav}
                  >
                    {item.label}
                  </a>
                ) : (
                  <Link
                    key={item.href}
                    to={`/${item.href}`}
                    className="public-sidebar__link"
                    onClick={closeMobileNav}
                  >
                    {item.label}
                  </Link>
                ),
              )}
            </nav>

            {isAuthenticated ? (
              <Link
                to="/app/dashboard"
                className="primary-btn public-drawer__login"
                onClick={closeMobileNav}
              >
                Ouvrir mon cockpit
              </Link>
            ) : (
              <>
                <Link
                  to="/inscription"
                  className="primary-btn public-drawer__login"
                  onClick={closeMobileNav}
                >
                  Créer mon espace
                </Link>

                <button
                  type="button"
                  className="secondary-btn public-drawer__login"
                  onClick={openLoginModalFromDrawer}
                >
                  Se connecter
                </button>
              </>
            )}
          </div>
        </MobileNavDrawer>
      </div>

      <AuthModal open={isAuthModalOpen} onClose={closeLoginModal} />
    </div>
  );
}
