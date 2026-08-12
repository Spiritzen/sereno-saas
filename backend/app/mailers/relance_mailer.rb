# frozen_string_literal: true

# Relances v1a — un seul mail : le rappel manuel envoyé au clic sur
# "Relancer". `relance` est déjà persistée par RelanceService AVANT l'appel
# (objet/destinataire déjà figés dessus) — ce mailer ne fait que rendre ce
# qui a déjà été décidé, jamais de nouvelle logique métier ici.
class RelanceMailer < ApplicationMailer
  def rappel(relance)
    @relance = relance
    @facture = relance.facture
    @client = @facture.client
    # Même dérivation que partout ailleurs (PaiementSyntheseService) —
    # jamais un recalcul maison du reste dû dans un mail.
    @reste_a_payer = PaiementSyntheseService.new(facture: @facture).call.reste_a_payer

    mail(to: relance.destinataire_email, subject: relance.objet)
  end
end
