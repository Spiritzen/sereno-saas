class AddWebhookSecretChiffreToPlateformesAgreees < ActiveRecord::Migration[8.1]
  def change
    # R3 (B3.3) — secret de signature webhook, PAR ORGANISATION (décision
    # actée : pas de secret global). Champ DÉDIÉ plutôt qu'une clé ajoutée
    # dans le JSON de `credentials_chiffres` : ce dernier est aujourd'hui un
    # champ TEXTE opaque (une simple valeur, pas un objet structuré — cf.
    # plateforme_agreee_spec.rb, round-trip sur une String brute), utilisé
    # pour les identifiants de compte PA. Y mélanger un second secret de
    # nature différente (signature entrante vs identifiants sortants)
    # casserait ce contrat et le test de round-trip existant. Chiffré au
    # repos via AR::Encryption (encrypts, non déterministe — jamais recherché
    # ni comparé en base), même mécanisme que credentials_chiffres.
    add_column :plateformes_agreees, :webhook_secret_chiffre, :text
  end
end
