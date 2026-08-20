import type { ReactNode } from "react";

type SectionHeadingProps = {
  title: string;
  subtitle?: string;
  action?: ReactNode;
  // D1 (§4.E/§4.F) — icône décorative optionnelle avant le titre (ex. Factures
  // récentes, Échéances). Toujours décorative : le titre porte seul le sens,
  // donc l'icône est rendue aria-hidden par l'appelant, jamais ici.
  icon?: ReactNode;
};

// Grammaire visuelle (§6) : en-tête de section réutilisé partout où une
// zone de contenu a besoin d'un titre + sous-titre + action optionnelle
// (aujourd'hui : Échéances à venir, Factures récentes du Dashboard). Aucune
// logique métier, aucun appel API — purement structurel.
export function SectionHeading({ title, subtitle, action, icon }: SectionHeadingProps) {
  return (
    <div className="section-title">
      <div>
        <h2>
          {icon}
          {title}
        </h2>
        {subtitle && <span>{subtitle}</span>}
      </div>

      {action}
    </div>
  );
}
