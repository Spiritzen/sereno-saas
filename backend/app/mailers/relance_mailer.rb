# frozen_string_literal: true

# Relances v1a (manuel) + v1b (auto) — un seul mail : le rappel envoyé au
# clic sur "Relancer" OU par RelanceEnvoiJob. `relance` est déjà persistée
# par RelanceService AVANT l'appel (objet/destinataire déjà figés dessus) —
# ce mailer ne fait que rendre ce qui a déjà été décidé, jamais de nouvelle
# logique métier ici.
#
# `delivery_method:` (v1b, optionnel) — override PAR MESSAGE, jamais une
# mutation globale de la config : cf. RelanceService#delivery_method_override
# pour le pourquoi (job de fond, jamais d'onglet navigateur). nil (défaut,
# chemin manuel v1a) laisse la config réelle inchangée — comportement
# strictement identique à avant.
#
# `url_portail:` (fast-follow 15/08/2026, optionnel) — URL ABSOLUE déjà
# construite par RelanceService (PortailFactureToken.url_publique), jamais
# recalculée ici : ce mailer ne fait que rendre ce qui a déjà été décidé
# (même discipline que `relance.objet`, déjà figé avant l'appel). nil
# uniquement défensif (ne devrait plus arriver, cf. RelanceService) — les
# templates n'affichent alors simplement pas le bloc lien.
class RelanceMailer < ApplicationMailer
  def rappel(relance, delivery_method: nil, url_portail: nil)
    @relance = relance
    @facture = relance.facture
    @client = @facture.client
    @url_portail = url_portail
    # Même dérivation que partout ailleurs (PaiementSyntheseService) —
    # jamais un recalcul maison du reste dû dans un mail.
    @reste_a_payer = PaiementSyntheseService.new(facture: @facture).call.reste_a_payer

    mail(to: relance.destinataire_email, subject: relance.objet, delivery_method: delivery_method)
  end
end
