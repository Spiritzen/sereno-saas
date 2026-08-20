import { useId } from "react";

type SerenoLogoProps = {
  size?: number;
  className?: string;
};

// Marque Sereno — Correction C (§6
// docs/local/prompt_claude_code_reprise_dashboard_d0_direction_artistique.txt
// puis prompt_claude_code_dashboard_d0_1_alignement_shell.txt §6, qui corrige
// le premier jet). AUCUN fichier vectoriel n'a été fourni : la seule
// référence reste `docs/FinalSereno.png`, observée à fort zoom. Le mark
// cible n'est ni une fleur/croix à 4 pétales (version précédente, jugée
// infidèle), ni un "S" typographique : c'est un monogramme compact en deux
// rubans opposés qui s'entrelacent (un mouvement en haut-droite, son miroir
// en bas-gauche, rotation 180° autour du même centre mais DÉCALÉ pour
// laisser un vide central lisible plutôt que deux pointes qui se touchent),
// dégradé du violet profond au violet lumineux.
//
// Cette reconstruction reste une VECTORISATION RAISONNÉE depuis un
// screenshot PNG, à l'œil — pas une extraction exacte de tracés. Fidélité
// raisonnable, pas garantie au trait près (signalé au rapport).
//
// role="img" + aria-label INCONDITIONNELS (jamais aria-hidden) : dans la
// sidebar repliée, ce mark est le SEUL porteur du nom accessible — aucun
// texte "Sereno" adjacent dans cet état (cf. Sidebar.tsx, .logo-title n'est
// rendu que si isExpanded). Comportement déjà testé, conservé à l'identique.
export function SerenoLogo({ size = 38, className }: SerenoLogoProps) {
  const gradientId = useId();

  // Un seul ruban, dessiné en haut-droite (tête arrondie côté (19,4), pointe
  // effilée qui s'arrête à (10.5,13.5) — PAS au centre exact (12,12), pour
  // que la copie tournée à 180° laisse un vide visible plutôt que deux
  // pointes confondues). Répété une fois par rotation 180° autour du centre
  // du viewBox pour former le second ruban, en bas-gauche.
  const ruban =
    "M10.5,13.5 C11,9 13.5,5 18,4.5 C20.5,4.2 21.3,7.8 19,9.8 C16.2,12.2 13,13 10.5,13.5 Z";

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      role="img"
      aria-label="Sereno"
      className={className}
    >
      <defs>
        <linearGradient id={gradientId} x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" style={{ stopColor: "var(--color-brand)" }} />
          <stop offset="100%" style={{ stopColor: "var(--color-brand-light)" }} />
        </linearGradient>
      </defs>

      <path d={ruban} fill={`url(#${gradientId})`} />
      <path d={ruban} fill={`url(#${gradientId})`} transform="rotate(180 12 12)" opacity="0.85" />
    </svg>
  );
}
