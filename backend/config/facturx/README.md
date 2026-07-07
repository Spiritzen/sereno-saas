# Factur-X / PDF-A assets

Ce dossier contient les assets de conformité embarqués par Sereno.

## sRGB.icc

Profil ICC sRGB utilisé pour l'OutputIntent PDF/A-3 lors du packaging Factur-X.

Le service `FactureEmissionService` cherche ce fichier en priorité via :

`Rails.root.join("config", "facturx", "sRGB.icc")`

Objectif :
- ne pas dépendre d'un profil ICC installé sur Windows, Linux ou macOS ;
- rendre l'émission Factur-X portable en déploiement ;
- éviter une rupture en production sur un serveur minimal.

Source actuelle :
- Compact ICC Profiles
- profil : `sRGB-v2-magic.icc`
- licence : CC0-1.0

Le fichier est renommé en `sRGB.icc` pour correspondre au chemin attendu par le service Rails.
