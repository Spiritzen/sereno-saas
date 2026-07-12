# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_12_124139) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "abonnements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date_debut", null: false
    t.date "date_fin"
    t.string "id_stripe", limit: 100
    t.uuid "organisation_id", null: false
    t.string "plan", limit: 20, default: "gratuit", null: false
    t.decimal "prix_mensuel", precision: 8, scale: 2
    t.string "statut", limit: 20, default: "en_essai", null: false
    t.datetime "updated_at", null: false
    t.index ["id_stripe"], name: "index_abonnements_on_id_stripe"
    t.index ["organisation_id"], name: "index_abonnements_on_organisation_id"
    t.check_constraint "plan::text = ANY (ARRAY['gratuit'::character varying, 'pro'::character varying]::text[])", name: "check_abonnements_plan"
    t.check_constraint "prix_mensuel IS NULL OR prix_mensuel >= 0::numeric", name: "check_abonnements_prix_mensuel_positive"
    t.check_constraint "statut::text = ANY (ARRAY['en_essai'::character varying, 'actif'::character varying, 'suspendu'::character varying, 'annule'::character varying]::text[])", name: "check_abonnements_statut"
  end

  create_table "acomptes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "client_id", null: false
    t.datetime "created_at", null: false
    t.date "date_emission"
    t.uuid "devis_id"
    t.uuid "facture_id"
    t.decimal "montant_ht", precision: 12, scale: 2, null: false
    t.decimal "montant_ttc", precision: 12, scale: 2, null: false
    t.decimal "montant_tva", precision: 12, scale: 2, null: false
    t.string "numero", limit: 30
    t.uuid "organisation_id", null: false
    t.decimal "pourcentage", precision: 5, scale: 2
    t.string "statut", limit: 20, default: "brouillon", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_acomptes_on_client_id"
    t.index ["devis_id"], name: "index_acomptes_on_devis_id"
    t.index ["facture_id"], name: "index_acomptes_on_facture_id"
    t.index ["organisation_id", "client_id"], name: "index_acomptes_on_organisation_id_and_client_id"
    t.index ["organisation_id", "devis_id"], name: "index_acomptes_on_organisation_id_and_devis_id"
    t.index ["organisation_id", "facture_id"], name: "index_acomptes_on_organisation_id_and_facture_id"
    t.index ["organisation_id", "numero"], name: "index_acomptes_unique_numero_by_org", unique: true, where: "(numero IS NOT NULL)"
    t.index ["organisation_id"], name: "index_acomptes_on_organisation_id"
    t.check_constraint "montant_ht >= 0::numeric", name: "check_acomptes_montant_ht_positive"
    t.check_constraint "montant_ttc >= 0::numeric", name: "check_acomptes_montant_ttc_positive"
    t.check_constraint "montant_tva >= 0::numeric", name: "check_acomptes_montant_tva_positive"
    t.check_constraint "pourcentage IS NULL OR pourcentage > 0::numeric AND pourcentage <= 100::numeric", name: "check_acomptes_pourcentage_range"
    t.check_constraint "statut::text = ANY (ARRAY['brouillon'::character varying, 'emis'::character varying, 'encaisse'::character varying, 'deduit'::character varying]::text[])", name: "check_acomptes_statut"
  end

  create_table "avoirs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "client_id", null: false
    t.datetime "created_at", null: false
    t.date "date_emission"
    t.datetime "emis_at"
    t.uuid "facture_id", null: false
    t.string "motif", null: false
    t.string "numero", limit: 30
    t.uuid "organisation_id", null: false
    t.string "pdf_url", limit: 500
    t.string "statut", limit: 30, default: "brouillon", null: false
    t.decimal "total_ht", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "total_ttc", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "total_tva", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.string "xml_url", limit: 500
    t.index ["client_id"], name: "index_avoirs_on_client_id"
    t.index ["facture_id"], name: "index_avoirs_on_facture_id"
    t.index ["organisation_id", "client_id"], name: "index_avoirs_on_organisation_id_and_client_id"
    t.index ["organisation_id", "facture_id"], name: "index_avoirs_on_organisation_id_and_facture_id"
    t.index ["organisation_id", "numero"], name: "index_avoirs_unique_numero_by_org", unique: true, where: "(numero IS NOT NULL)"
    t.index ["organisation_id"], name: "index_avoirs_on_organisation_id"
    t.check_constraint "statut::text = ANY (ARRAY['brouillon'::character varying, 'emise'::character varying, 'deposee'::character varying, 'recue'::character varying, 'mise_a_disposition'::character varying, 'approuvee'::character varying, 'refusee'::character varying, 'en_litige'::character varying, 'encaissee'::character varying, 'archivee'::character varying, 'annulee'::character varying]::text[])", name: "check_avoirs_statut"
    t.check_constraint "total_ht >= 0::numeric", name: "check_avoirs_total_ht_positive"
    t.check_constraint "total_ttc >= 0::numeric", name: "check_avoirs_total_ttc_positive"
    t.check_constraint "total_tva >= 0::numeric", name: "check_avoirs_total_tva_positive"
  end

  create_table "clients", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "adresse_ligne1", null: false
    t.string "adresse_ligne2"
    t.string "code_postal", limit: 10, null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "identifiant_routage_pa", limit: 100
    t.text "notes"
    t.string "numero_tva", limit: 20
    t.uuid "organisation_id", null: false
    t.string "pays", limit: 2, default: "FR", null: false
    t.string "raison_sociale", null: false
    t.string "siret", limit: 14
    t.string "statut", limit: 20, default: "actif", null: false
    t.string "telephone", limit: 20
    t.string "type", limit: 20, default: "entreprise", null: false
    t.datetime "updated_at", null: false
    t.string "ville", limit: 100, null: false
    t.index ["identifiant_routage_pa"], name: "index_clients_on_identifiant_routage_pa"
    t.index ["organisation_id", "raison_sociale"], name: "index_clients_on_organisation_id_and_raison_sociale"
    t.index ["organisation_id", "siret"], name: "index_clients_on_organisation_id_and_siret"
    t.index ["organisation_id"], name: "index_clients_on_organisation_id"
    t.check_constraint "char_length(pays::text) = 2", name: "check_clients_pays_length"
    t.check_constraint "siret IS NULL OR char_length(siret::text) = 14", name: "check_clients_siret_length"
    t.check_constraint "statut::text = ANY (ARRAY['actif'::character varying, 'archive'::character varying]::text[])", name: "check_clients_statut"
    t.check_constraint "type::text = ANY (ARRAY['entreprise'::character varying, 'particulier'::character varying, 'public'::character varying]::text[])", name: "check_clients_type"
  end

  create_table "contacts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "client_id", null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "fonction", limit: 100
    t.string "nom", limit: 100, null: false
    t.uuid "organisation_id", null: false
    t.string "prenom", limit: 100
    t.boolean "principal", default: false, null: false
    t.string "telephone", limit: 20
    t.datetime "updated_at", null: false
    t.index ["client_id", "principal"], name: "index_contacts_on_client_id_and_principal"
    t.index ["client_id"], name: "index_contacts_on_client_id"
    t.index ["email"], name: "index_contacts_on_email"
    t.index ["organisation_id", "client_id"], name: "index_contacts_on_organisation_id_and_client_id"
    t.index ["organisation_id"], name: "index_contacts_on_organisation_id"
  end

  create_table "devis", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "client_id", null: false
    t.text "conditions"
    t.datetime "created_at", null: false
    t.date "date_emission"
    t.date "date_validite"
    t.string "numero", limit: 30
    t.string "objet"
    t.uuid "organisation_id", null: false
    t.string "statut", limit: 20, default: "brouillon", null: false
    t.decimal "total_ht", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "total_ttc", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "total_tva", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_devis_on_client_id"
    t.index ["organisation_id", "client_id"], name: "index_devis_on_organisation_id_and_client_id"
    t.index ["organisation_id", "numero"], name: "index_devis_on_organisation_id_and_numero", unique: true, where: "(numero IS NOT NULL)"
    t.index ["organisation_id"], name: "index_devis_on_organisation_id"
    t.check_constraint "statut::text = ANY (ARRAY['brouillon'::character varying, 'envoye'::character varying, 'accepte'::character varying, 'refuse'::character varying, 'expire'::character varying]::text[])", name: "check_devis_statut"
    t.check_constraint "total_ht >= 0::numeric", name: "check_devis_total_ht_positive"
    t.check_constraint "total_ttc >= 0::numeric", name: "check_devis_total_ttc_positive"
    t.check_constraint "total_tva >= 0::numeric", name: "check_devis_total_tva_positive"
  end

  create_table "e_reporting", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "montant_total", precision: 14, scale: 2, default: "0.0", null: false
    t.integer "nb_operations", default: 0, null: false
    t.uuid "organisation_id", null: false
    t.jsonb "payload"
    t.date "periode_debut", null: false
    t.date "periode_fin", null: false
    t.string "statut", limit: 20, default: "en_attente", null: false
    t.datetime "transmis_at"
    t.string "type", limit: 20, null: false
    t.datetime "updated_at", null: false
    t.index ["organisation_id", "statut"], name: "index_e_reporting_on_org_and_statut"
    t.index ["organisation_id", "type", "periode_debut", "periode_fin"], name: "index_e_reporting_on_org_type_and_period"
    t.index ["organisation_id"], name: "index_e_reporting_on_organisation_id"
    t.check_constraint "montant_total >= 0::numeric", name: "check_e_reporting_montant_total_positive"
    t.check_constraint "nb_operations >= 0", name: "check_e_reporting_nb_operations_positive"
    t.check_constraint "periode_fin >= periode_debut", name: "check_e_reporting_periode_coherente"
    t.check_constraint "statut::text = ANY (ARRAY['en_attente'::character varying, 'transmis'::character varying, 'accepte'::character varying, 'rejete'::character varying]::text[])", name: "check_e_reporting_statut"
    t.check_constraint "type::text = ANY (ARRAY['transactions'::character varying, 'paiements'::character varying]::text[])", name: "check_e_reporting_type"
  end

  create_table "evenement_facture", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "code_statut_pa", limit: 50
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.uuid "facture_id", null: false
    t.uuid "organisation_id", null: false
    t.jsonb "payload"
    t.string "source", limit: 20, default: "interne", null: false
    t.string "statut", limit: 30, null: false
    t.uuid "utilisateur_id"
    t.index ["facture_id", "created_at"], name: "index_evenement_facture_on_facture_and_created_at"
    t.index ["facture_id"], name: "index_evenement_facture_on_facture_id"
    t.index ["organisation_id", "created_at"], name: "index_evenement_facture_on_org_and_created_at"
    t.index ["organisation_id", "facture_id"], name: "index_evenement_facture_on_org_and_facture"
    t.index ["organisation_id"], name: "index_evenement_facture_on_organisation_id"
    t.index ["utilisateur_id"], name: "index_evenement_facture_on_utilisateur_id"
    t.check_constraint "source::text = ANY (ARRAY['interne'::character varying, 'pa'::character varying, 'webhook'::character varying, 'sandbox'::character varying]::text[])", name: "check_evenement_facture_source"
    t.check_constraint "statut::text = ANY (ARRAY['brouillon'::character varying, 'emise'::character varying, 'deposee'::character varying, 'recue'::character varying, 'mise_a_disposition'::character varying, 'approuvee'::character varying, 'refusee'::character varying, 'en_litige'::character varying, 'encaissee'::character varying, 'archivee'::character varying, 'annulee'::character varying]::text[])", name: "check_evenement_facture_statut"
  end

  create_table "factures", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "client_id", null: false
    t.string "conditions_paiement"
    t.datetime "created_at", null: false
    t.date "date_echeance"
    t.date "date_emission"
    t.uuid "devis_id"
    t.string "devise", limit: 3, default: "EUR", null: false
    t.datetime "emise_at"
    t.string "format", limit: 20, default: "factur_x", null: false
    t.text "mentions"
    t.decimal "montant_paye", precision: 12, scale: 2, default: "0.0", null: false
    t.string "numero", limit: 30
    t.uuid "organisation_id", null: false
    t.string "pdf_url", limit: 500
    t.string "statut", limit: 30, default: "brouillon", null: false
    t.decimal "total_ht", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "total_ttc", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "total_tva", precision: 12, scale: 2, default: "0.0", null: false
    t.string "type_document", limit: 20, default: "facture", null: false
    t.datetime "updated_at", null: false
    t.string "xml_url", limit: 500
    t.index ["client_id"], name: "index_factures_on_client_id"
    t.index ["devis_id"], name: "index_factures_on_devis_id"
    t.index ["organisation_id", "client_id"], name: "index_factures_on_organisation_id_and_client_id"
    t.index ["organisation_id", "numero"], name: "index_factures_unique_numero_by_org", unique: true, where: "(numero IS NOT NULL)"
    t.index ["organisation_id"], name: "index_factures_on_organisation_id"
    t.check_constraint "char_length(devise::text) = 3", name: "check_factures_devise_length"
    t.check_constraint "format::text = ANY (ARRAY['factur_x'::character varying, 'ubl'::character varying, 'cii'::character varying]::text[])", name: "check_factures_format"
    t.check_constraint "montant_paye >= 0::numeric", name: "check_factures_montant_paye_positive"
    t.check_constraint "statut::text = ANY (ARRAY['brouillon'::character varying, 'emise'::character varying, 'deposee'::character varying, 'recue'::character varying, 'mise_a_disposition'::character varying, 'approuvee'::character varying, 'refusee'::character varying, 'en_litige'::character varying, 'encaissee'::character varying, 'archivee'::character varying, 'annulee'::character varying]::text[])", name: "check_factures_statut"
    t.check_constraint "total_ht >= 0::numeric", name: "check_factures_total_ht_positive"
    t.check_constraint "total_ttc >= 0::numeric", name: "check_factures_total_ttc_positive"
    t.check_constraint "total_tva >= 0::numeric", name: "check_factures_total_tva_positive"
    t.check_constraint "type_document::text = ANY (ARRAY['facture'::character varying, 'acompte'::character varying]::text[])", name: "check_factures_type_document"
  end

  create_table "ligne_avoir", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "avoir_id", null: false
    t.datetime "created_at", null: false
    t.string "designation", null: false
    t.uuid "organisation_id", null: false
    t.integer "position", default: 0, null: false
    t.decimal "prix_unitaire_ht", precision: 12, scale: 2, null: false
    t.decimal "quantite", precision: 10, scale: 2, default: "1.0", null: false
    t.decimal "taux_tva", precision: 5, scale: 2, null: false
    t.decimal "total_ht", precision: 12, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["avoir_id", "position"], name: "index_ligne_avoir_on_avoir_and_position"
    t.index ["avoir_id"], name: "index_ligne_avoir_on_avoir_id"
    t.index ["organisation_id", "avoir_id"], name: "index_ligne_avoir_on_org_and_avoir"
    t.index ["organisation_id"], name: "index_ligne_avoir_on_organisation_id"
    t.check_constraint "prix_unitaire_ht >= 0::numeric", name: "check_ligne_avoir_prix_unitaire_ht_positive"
    t.check_constraint "quantite > 0::numeric", name: "check_ligne_avoir_quantite_positive"
    t.check_constraint "taux_tva >= 0::numeric", name: "check_ligne_avoir_taux_tva_positive"
    t.check_constraint "total_ht >= 0::numeric", name: "check_ligne_avoir_total_ht_positive"
  end

  create_table "ligne_devis", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "designation", null: false
    t.uuid "devis_id", null: false
    t.uuid "organisation_id", null: false
    t.integer "position", default: 0, null: false
    t.decimal "prix_unitaire_ht", precision: 12, scale: 2, null: false
    t.uuid "produit_id"
    t.decimal "quantite", precision: 10, scale: 2, default: "1.0", null: false
    t.decimal "taux_tva", precision: 5, scale: 2, null: false
    t.decimal "total_ht", precision: 12, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["devis_id", "position"], name: "index_ligne_devis_on_devis_id_and_position"
    t.index ["devis_id"], name: "index_ligne_devis_on_devis_id"
    t.index ["organisation_id", "devis_id"], name: "index_ligne_devis_on_organisation_id_and_devis_id"
    t.index ["organisation_id"], name: "index_ligne_devis_on_organisation_id"
    t.index ["produit_id"], name: "index_ligne_devis_on_produit_id"
    t.check_constraint "prix_unitaire_ht >= 0::numeric", name: "check_ligne_devis_prix_unitaire_ht_positive"
    t.check_constraint "quantite > 0::numeric", name: "check_ligne_devis_quantite_positive"
    t.check_constraint "taux_tva >= 0::numeric", name: "check_ligne_devis_taux_tva_positive"
    t.check_constraint "total_ht >= 0::numeric", name: "check_ligne_devis_total_ht_positive"
  end

  create_table "ligne_facture", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "designation", null: false
    t.uuid "facture_id", null: false
    t.decimal "montant_tva", precision: 12, scale: 2, null: false
    t.uuid "organisation_id", null: false
    t.integer "position", default: 0, null: false
    t.decimal "prix_unitaire_ht", precision: 12, scale: 2, null: false
    t.uuid "produit_id"
    t.decimal "quantite", precision: 10, scale: 2, default: "1.0", null: false
    t.decimal "taux_tva", precision: 5, scale: 2, null: false
    t.decimal "total_ht", precision: 12, scale: 2, null: false
    t.decimal "total_ttc", precision: 12, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["facture_id", "position"], name: "index_ligne_facture_on_facture_and_position"
    t.index ["facture_id"], name: "index_ligne_facture_on_facture_id"
    t.index ["organisation_id", "facture_id"], name: "index_ligne_facture_on_org_and_facture"
    t.index ["organisation_id"], name: "index_ligne_facture_on_organisation_id"
    t.index ["produit_id"], name: "index_ligne_facture_on_produit_id"
    t.check_constraint "montant_tva >= 0::numeric", name: "check_ligne_facture_montant_tva_positive"
    t.check_constraint "prix_unitaire_ht >= 0::numeric", name: "check_ligne_facture_prix_unitaire_ht_positive"
    t.check_constraint "quantite > 0::numeric", name: "check_ligne_facture_quantite_positive"
    t.check_constraint "taux_tva >= 0::numeric", name: "check_ligne_facture_taux_tva_positive"
    t.check_constraint "total_ht >= 0::numeric", name: "check_ligne_facture_total_ht_positive"
    t.check_constraint "total_ttc >= 0::numeric", name: "check_ligne_facture_total_ttc_positive"
  end

  create_table "numerotations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "annee", null: false
    t.datetime "created_at", null: false
    t.integer "dernier_numero", default: 0, null: false
    t.uuid "organisation_id", null: false
    t.string "prefixe", limit: 20
    t.string "type_document", limit: 20, null: false
    t.datetime "updated_at", null: false
    t.index ["organisation_id", "type_document", "annee"], name: "index_numerotations_unique_sequence", unique: true
    t.index ["organisation_id"], name: "index_numerotations_on_organisation_id"
    t.check_constraint "annee >= 2000", name: "check_numerotations_annee"
    t.check_constraint "dernier_numero >= 0", name: "check_numerotations_dernier_numero_positive"
    t.check_constraint "type_document::text = ANY (ARRAY['facture'::character varying, 'avoir'::character varying, 'acompte'::character varying, 'devis'::character varying]::text[])", name: "check_numerotations_type_document"
  end

  create_table "organisations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "adresse_ligne1", null: false
    t.string "adresse_ligne2"
    t.string "code_postal", limit: 10, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "forme_juridique", limit: 50
    t.string "iban", limit: 34
    t.string "identifiant_pa", limit: 100
    t.string "logo_url", limit: 500
    t.text "mentions_legales"
    t.string "numero_tva", limit: 20
    t.string "pays", limit: 2, default: "FR", null: false
    t.string "raison_sociale", null: false
    t.string "regime_tva", limit: 20, default: "franchise", null: false
    t.string "siret", limit: 14, null: false
    t.string "telephone", limit: 20
    t.datetime "updated_at", null: false
    t.string "ville", limit: 100, null: false
    t.index ["siret"], name: "index_organisations_on_siret", unique: true
    t.check_constraint "char_length(siret::text) = 14", name: "check_organisations_siret_length"
    t.check_constraint "regime_tva::text = ANY (ARRAY['franchise'::character varying, 'reel_simplifie'::character varying, 'reel_normal'::character varying]::text[])", name: "check_organisations_regime_tva"
  end

  create_table "paiements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date_paiement", null: false
    t.uuid "facture_id", null: false
    t.string "methode", limit: 20, null: false
    t.decimal "montant", precision: 12, scale: 2, null: false
    t.uuid "organisation_id", null: false
    t.string "reference", limit: 100
    t.datetime "updated_at", null: false
    t.index ["facture_id"], name: "index_paiements_on_facture_id"
    t.index ["organisation_id", "date_paiement"], name: "index_paiements_on_org_and_date"
    t.index ["organisation_id", "facture_id"], name: "index_paiements_on_org_and_facture"
    t.index ["organisation_id"], name: "index_paiements_on_organisation_id"
    t.check_constraint "methode::text = ANY (ARRAY['virement'::character varying, 'carte'::character varying, 'cheque'::character varying, 'especes'::character varying, 'prelevement'::character varying]::text[])", name: "check_paiements_methode"
    t.check_constraint "montant > 0::numeric", name: "check_paiements_montant_positive"
  end

  create_table "plateformes_agreees", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "api_url", null: false
    t.datetime "connecte_at"
    t.datetime "created_at", null: false
    t.text "credentials_chiffres"
    t.string "fournisseur", limit: 50, null: false
    t.string "identifiant_compte"
    t.uuid "organisation_id", null: false
    t.string "statut", limit: 20, default: "connecte", null: false
    t.string "type", limit: 20, default: "pa", null: false
    t.datetime "updated_at", null: false
    t.index ["organisation_id"], name: "index_plateformes_agreees_on_organisation_id", unique: true
    t.check_constraint "statut::text = ANY (ARRAY['connecte'::character varying, 'deconnecte'::character varying, 'erreur'::character varying]::text[])", name: "check_plateformes_agreees_statut"
    t.check_constraint "type::text = ANY (ARRAY['pa'::character varying, 'chorus_pro'::character varying]::text[])", name: "check_plateformes_agreees_type"
  end

  create_table "produits", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "actif", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "designation", null: false
    t.uuid "organisation_id", null: false
    t.decimal "prix_unitaire_ht", precision: 12, scale: 2, null: false
    t.uuid "taux_tva_id"
    t.string "unite", limit: 20, default: "unité"
    t.datetime "updated_at", null: false
    t.index ["organisation_id", "designation"], name: "index_produits_on_organisation_id_and_designation"
    t.index ["organisation_id"], name: "index_produits_on_organisation_id"
    t.index ["taux_tva_id"], name: "index_produits_on_taux_tva_id"
    t.check_constraint "prix_unitaire_ht >= 0::numeric", name: "check_produits_prix_unitaire_ht_positive"
    t.check_constraint "unite IS NULL OR (unite::text = ANY (ARRAY['unité'::character varying, 'heure'::character varying, 'jour'::character varying, 'forfait'::character varying]::text[]))", name: "check_produits_unite"
  end

  create_table "relances", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "canal", limit: 20, default: "email", null: false
    t.datetime "created_at", null: false
    t.date "date_planifiee", null: false
    t.datetime "envoyee_at"
    t.uuid "facture_id", null: false
    t.integer "niveau", limit: 2, default: 1, null: false
    t.uuid "organisation_id", null: false
    t.string "statut", limit: 20, default: "planifiee", null: false
    t.datetime "updated_at", null: false
    t.index ["facture_id", "niveau"], name: "index_relances_on_facture_and_niveau"
    t.index ["facture_id"], name: "index_relances_on_facture_id"
    t.index ["organisation_id", "facture_id"], name: "index_relances_on_org_and_facture"
    t.index ["organisation_id", "statut"], name: "index_relances_on_org_and_statut"
    t.index ["organisation_id"], name: "index_relances_on_organisation_id"
    t.check_constraint "canal::text = ANY (ARRAY['email'::character varying, 'courrier'::character varying]::text[])", name: "check_relances_canal"
    t.check_constraint "niveau >= 1 AND niveau <= 3", name: "check_relances_niveau"
    t.check_constraint "statut::text = ANY (ARRAY['planifiee'::character varying, 'envoyee'::character varying, 'echec'::character varying]::text[])", name: "check_relances_statut"
  end

  create_table "sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expire_at", null: false
    t.string "ip_adresse", limit: 45
    t.uuid "organisation_id", null: false
    t.string "refresh_token_hash", null: false
    t.datetime "revoque_at"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.uuid "utilisateur_id", null: false
    t.index ["expire_at"], name: "index_sessions_on_expire_at"
    t.index ["organisation_id"], name: "index_sessions_on_organisation_id"
    t.index ["refresh_token_hash"], name: "index_sessions_on_refresh_token_hash", unique: true
    t.index ["utilisateur_id", "organisation_id"], name: "index_sessions_on_utilisateur_id_and_organisation_id"
    t.index ["utilisateur_id"], name: "index_sessions_on_utilisateur_id"
  end

  create_table "taux_tvas", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "libelle", limit: 50, null: false
    t.string "mention_exoneration"
    t.uuid "organisation_id", null: false
    t.boolean "par_defaut", default: false, null: false
    t.decimal "taux", precision: 5, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["organisation_id", "libelle"], name: "index_taux_tvas_on_organisation_id_and_libelle"
    t.index ["organisation_id"], name: "index_taux_tvas_on_organisation_id"
    t.index ["organisation_id"], name: "index_taux_tvas_unique_default_by_org", unique: true, where: "(par_defaut = true)"
    t.check_constraint "taux >= 0::numeric", name: "check_taux_tvas_taux_positive"
  end

  create_table "transmission_pa", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "accuse_reception"
    t.uuid "avoir_id"
    t.datetime "created_at", null: false
    t.string "direction", limit: 10, default: "sortant", null: false
    t.uuid "facture_id"
    t.string "format", limit: 20, default: "factur_x", null: false
    t.uuid "idempotency_key", null: false
    t.string "identifiant_pa", limit: 100
    t.text "message_erreur"
    t.uuid "organisation_id", null: false
    t.uuid "plateforme_agreee_id", null: false
    t.string "statut", limit: 30, default: "en_attente", null: false
    t.integer "tentative", default: 0, null: false
    t.datetime "transmis_at"
    t.datetime "updated_at", null: false
    t.index ["avoir_id"], name: "index_transmission_pa_on_avoir_id"
    t.index ["facture_id"], name: "index_transmission_pa_on_facture_id"
    t.index ["idempotency_key"], name: "index_transmission_pa_on_idempotency_key", unique: true
    t.index ["organisation_id", "avoir_id"], name: "index_transmission_pa_on_org_and_avoir"
    t.index ["organisation_id", "facture_id", "plateforme_agreee_id"], name: "index_transmission_pa_on_org_facture_pa_active", unique: true, where: "((statut)::text <> 'erreur'::text)"
    t.index ["organisation_id", "facture_id"], name: "index_transmission_pa_on_org_and_facture"
    t.index ["organisation_id", "statut"], name: "index_transmission_pa_on_org_and_statut"
    t.index ["organisation_id"], name: "index_transmission_pa_on_organisation_id"
    t.index ["plateforme_agreee_id"], name: "index_transmission_pa_on_plateforme_agreee_id"
    t.check_constraint "direction::text = ANY (ARRAY['sortant'::character varying, 'entrant'::character varying]::text[])", name: "check_transmission_pa_direction"
    t.check_constraint "facture_id IS NOT NULL AND avoir_id IS NULL OR facture_id IS NULL AND avoir_id IS NOT NULL", name: "check_transmission_pa_one_document_target"
    t.check_constraint "format::text = ANY (ARRAY['factur_x'::character varying, 'ubl'::character varying, 'cii'::character varying]::text[])", name: "check_transmission_pa_format"
    t.check_constraint "statut::text = ANY (ARRAY['en_attente'::character varying, 'depose'::character varying, 'accepte'::character varying, 'rejete'::character varying, 'erreur'::character varying]::text[])", name: "check_transmission_pa_statut"
  end

  create_table "utilisateurs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "actif", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "derniere_connexion_at"
    t.string "email", null: false
    t.string "mot_de_passe_hash", null: false
    t.string "nom", limit: 100, null: false
    t.uuid "organisation_id", null: false
    t.string "prenom", limit: 100, null: false
    t.string "role", limit: 20, default: "membre", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_utilisateurs_on_email", unique: true
    t.index ["organisation_id"], name: "index_utilisateurs_on_organisation_id"
    t.check_constraint "role::text = ANY (ARRAY['super_admin'::character varying, 'owner'::character varying, 'comptable'::character varying, 'membre'::character varying]::text[])", name: "check_utilisateurs_role"
  end

  add_foreign_key "abonnements", "organisations"
  add_foreign_key "acomptes", "clients"
  add_foreign_key "acomptes", "devis", column: "devis_id"
  add_foreign_key "acomptes", "factures"
  add_foreign_key "acomptes", "organisations"
  add_foreign_key "avoirs", "clients"
  add_foreign_key "avoirs", "factures"
  add_foreign_key "avoirs", "organisations"
  add_foreign_key "clients", "organisations"
  add_foreign_key "contacts", "clients"
  add_foreign_key "contacts", "organisations"
  add_foreign_key "devis", "clients"
  add_foreign_key "devis", "organisations"
  add_foreign_key "e_reporting", "organisations"
  add_foreign_key "evenement_facture", "factures"
  add_foreign_key "evenement_facture", "organisations"
  add_foreign_key "evenement_facture", "utilisateurs"
  add_foreign_key "factures", "clients"
  add_foreign_key "factures", "devis", column: "devis_id"
  add_foreign_key "factures", "organisations"
  add_foreign_key "ligne_avoir", "avoirs"
  add_foreign_key "ligne_avoir", "organisations"
  add_foreign_key "ligne_devis", "devis", column: "devis_id"
  add_foreign_key "ligne_devis", "organisations"
  add_foreign_key "ligne_devis", "produits"
  add_foreign_key "ligne_facture", "factures"
  add_foreign_key "ligne_facture", "organisations"
  add_foreign_key "ligne_facture", "produits"
  add_foreign_key "numerotations", "organisations"
  add_foreign_key "paiements", "factures"
  add_foreign_key "paiements", "organisations"
  add_foreign_key "plateformes_agreees", "organisations"
  add_foreign_key "produits", "organisations"
  add_foreign_key "produits", "taux_tvas"
  add_foreign_key "relances", "factures"
  add_foreign_key "relances", "organisations"
  add_foreign_key "sessions", "organisations"
  add_foreign_key "sessions", "utilisateurs"
  add_foreign_key "taux_tvas", "organisations"
  add_foreign_key "transmission_pa", "avoirs"
  add_foreign_key "transmission_pa", "factures"
  add_foreign_key "transmission_pa", "organisations"
  add_foreign_key "transmission_pa", "plateformes_agreees", column: "plateforme_agreee_id"
  add_foreign_key "utilisateurs", "organisations"
end
