import type { Utilisateur } from "../types/auth";

// Partagé Topbar/Sidebar (§6, grammaire visuelle) : les deux surfaces
// affichent désormais une identité utilisateur réelle — une seule source
// pour initiales/nom/rôle évite deux implémentations divergentes.
const ROLE_LABELS: Record<Utilisateur["role"], string> = {
  super_admin: "Super admin",
  owner: "Owner",
  comptable: "Comptable",
  membre: "Membre",
};

export function getUserInitials(utilisateur: Utilisateur | null): string {
  const first = utilisateur?.prenom?.[0] ?? "";
  const last = utilisateur?.nom?.[0] ?? "";
  const initials = `${first}${last}`.toUpperCase();

  if (initials.length > 0) {
    return initials;
  }

  return utilisateur?.email?.slice(0, 2).toUpperCase() ?? "SC";
}

export function getUserFullName(utilisateur: Utilisateur | null): string {
  return utilisateur ? `${utilisateur.prenom} ${utilisateur.nom}`.trim() : "Utilisateur";
}

export function getUserRoleLabel(utilisateur: Utilisateur | null): string {
  return utilisateur ? ROLE_LABELS[utilisateur.role] : "Connecté";
}
