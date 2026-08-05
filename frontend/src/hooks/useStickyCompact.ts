import { useEffect, useRef, useState } from "react";

export type UseStickyCompactResult = {
  sentinelRef: React.RefObject<HTMLDivElement | null>;
  sectionRef: React.RefObject<HTMLElement | null>;
  isEligibleForSticky: boolean;
  isCompact: boolean;
  spacerHeight: number;
};

// Extrait à l'identique de InvoiceLifecycleTimeline/CreditNoteLifecycleTimeline
// (duplication mécanique confirmée à l'audit Celestial Quiet Command) : LA
// MÉCANIQUE seule — aucun rendu, aucun texte métier. Chaque timeline reste un
// composant séparé (duplication sémantique volontaire, cf. leurs propres
// commentaires), mais partage désormais cette seule mécanique sticky/compact.
//
// Sentinelle de hauteur nulle juste avant le bloc : IntersectionObserver (pas
// de scroll-listener) détecte le moment où le bloc atteint le haut du
// viewport et devient collant, pour y synchroniser le passage en mode
// compact. rootMargin à -1px : la sentinelle "sort" du viewport une frame
// avant que `position: sticky; top: 0` ne prenne effet.
//
// Garde-fou — CORRECTIF boucle de scroll page courte : le sticky n'est activé
// QUE si le document a assez de hauteur pour que ça ait un sens (marge d'une
// hauteur d'écran). Sur un brouillon court, cette valeur reste false en
// permanence : le bloc ne colle jamais, ne compacte jamais — quel que soit ce
// que rapporte l'IntersectionObserver.
//
// Réservation de place — CORRECTIF boucle de scroll : quand le bloc compacte,
// sa propre hauteur en flux diminue (position: sticky ne retire PAS l'élément
// du flux comme le ferait `fixed` : il continue à réserver sa hauteur RENDUE
// à sa place). Sans compensation, cette diminution raccourcit le document
// pendant qu'on est collé -> remontée forcée -> le bloc redevient visible ->
// redécolle -> le document rallonge -> la remontée se reproduit : boucle
// infinie. Un espaceur, sibling APRÈS la section (à la charge de l'appelant),
// regonfle exactement de ce qu'elle a perdu.
export function useStickyCompact(): UseStickyCompactResult {
  const sentinelRef = useRef<HTMLDivElement | null>(null);
  const sectionRef = useRef<HTMLElement | null>(null);
  const [isStuck, setIsStuck] = useState(false);
  const [isEligibleForSticky, setIsEligibleForSticky] = useState(false);

  useEffect(() => {
    function evaluerEligibilite() {
      const hauteurViewport = window.innerHeight;
      const hauteurDocument = document.documentElement.scrollHeight;

      setIsEligibleForSticky(hauteurDocument > hauteurViewport * 2);
    }

    evaluerEligibilite();

    // ResizeObserver sur le document (pas un scroll-listener) : recalcule à
    // chaque changement de contenu et au redimensionnement de la fenêtre.
    const resizeObserver = new ResizeObserver(evaluerEligibilite);
    resizeObserver.observe(document.body);
    window.addEventListener("resize", evaluerEligibilite);

    return () => {
      resizeObserver.disconnect();
      window.removeEventListener("resize", evaluerEligibilite);
    };
  }, []);

  useEffect(() => {
    const sentinel = sentinelRef.current;

    if (!sentinel) {
      return;
    }

    const observer = new IntersectionObserver(
      ([entry]) => setIsStuck(isEligibleForSticky && !entry.isIntersecting),
      { threshold: 0, rootMargin: "-1px 0px 0px 0px" },
    );

    observer.observe(sentinel);

    return () => observer.disconnect();
  }, [isEligibleForSticky]);

  // isStuck seul ne suffit pas : sur une page devenue inéligible entre temps,
  // isStuck peut rester obsolète jusqu'à la prochaine intersection de la
  // sentinelle — isCompact est la vérité affichée ET utilisée pour la
  // réservation de place ci-dessous.
  const isCompact = isEligibleForSticky && isStuck;

  const fullHeightRef = useRef(0);
  const [spacerHeight, setSpacerHeight] = useState(0);

  useEffect(() => {
    const section = sectionRef.current;

    if (!section) {
      return;
    }

    function mesurer() {
      const hauteurActuelle = section!.offsetHeight;

      if (!isCompact) {
        fullHeightRef.current = hauteurActuelle;
        setSpacerHeight(0);
        return;
      }

      setSpacerHeight(Math.max(0, fullHeightRef.current - hauteurActuelle));
    }

    mesurer();

    const resizeObserver = new ResizeObserver(mesurer);
    resizeObserver.observe(section);

    return () => resizeObserver.disconnect();
  }, [isCompact]);

  return { sentinelRef, sectionRef, isEligibleForSticky, isCompact, spacerHeight };
}
