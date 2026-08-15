# frozen_string_literal: true

require "rails_helper"

RSpec.describe FecExportService do
  # Parse le contenu FEC produit en tableau de hashes {champ => valeur} —
  # split("\t", -1) est OBLIGATOIRE : les derniers champs (Montantdevise,
  # Idevise) sont vides, un split sans limite les tronquerait silencieusement.
  def parser_fec(contenu)
    lignes = contenu.split("\n")
    entete = lignes.first.split("\t", -1)
    lignes[1..].map { |ligne| entete.zip(ligne.split("\t", -1)).to_h }
  end

  def montant(valeur)
    BigDecimal(valeur.to_s.tr(",", "."))
  end

  let(:organisation) { create(:organisation) }
  let(:client) { create(:client, organisation: organisation, raison_sociale: "Client FEC") }

  describe "#call — vente" do
    it "produit une écriture VE équilibrée pour une facture standard (411 débit TTC == 707 + 44571 crédit)" do
      facture = create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago)

      resultat = described_class.new(
        organisation: organisation, debut: facture.date_emission - 1, fin: facture.date_emission + 1
      ).call
      lignes = parser_fec(resultat.contenu).select { |l| l["PieceRef"] == facture.numero }

      expect(lignes.size).to eq(3)
      expect(lignes.map { |l| l["EcritureNum"] }.uniq.size).to eq(1) # même écriture

      total_debit = lignes.sum { |l| montant(l["Debit"]) }
      total_credit = lignes.sum { |l| montant(l["Credit"]) }
      expect(total_debit).to eq(total_credit)
      expect(total_debit).to eq(BigDecimal(facture.total_ttc.to_s))

      ligne_411 = lignes.find { |l| l["CompteNum"] == "411" }
      expect(ligne_411["CompteLib"]).to eq("Clients")
      expect(ligne_411["CompAuxNum"]).to eq(client.siret)
      expect(ligne_411["CompAuxLib"]).to eq("Client FEC")
      expect(ligne_411["JournalCode"]).to eq("VE")
      expect(ligne_411["EcritureLib"]).to eq("Facture #{facture.numero} — Client FEC")

      ligne_707 = lignes.find { |l| l["CompteNum"] == "707" }
      expect(ligne_707["CompteLib"]).to eq("Ventes")
      expect(ligne_707["CompAuxNum"]).to eq("") # vide sur un compte général

      ligne_44571 = lignes.find { |l| l["CompteNum"] == "44571" }
      expect(ligne_44571["CompteLib"]).to eq("TVA collectée")
    end

    it "produit plusieurs paires 707/44571 pour une facture MULTI-TAUX, toujours équilibrée" do
      facture = create(:facture, organisation: organisation, client: client, date_echeance: 1.day.ago)
      create(:ligne_facture, facture: facture, organisation: organisation, taux_tva: 20, quantite: 1, prix_unitaire_ht: 100)
      create(:ligne_facture, facture: facture, organisation: organisation, taux_tva: 10, quantite: 1, prix_unitaire_ht: 50)
      facture.reload
      facture.update_columns(statut: "emise", numero: "FAC-MULTI-1", date_emission: Date.current, emise_at: Time.current)

      resultat = described_class.new(organisation: organisation, debut: Date.current, fin: Date.current).call
      lignes = parser_fec(resultat.contenu).select { |l| l["PieceRef"] == "FAC-MULTI-1" }

      expect(lignes.count { |l| l["CompteNum"] == "707" }).to eq(2)
      expect(lignes.count { |l| l["CompteNum"] == "44571" }).to eq(2)

      total_debit = lignes.sum { |l| montant(l["Debit"]) }
      total_credit = lignes.sum { |l| montant(l["Credit"]) }
      expect(total_debit).to eq(total_credit)
    end

    it "omet la ligne 44571 quand montant_tva est nul (franchise, taux 0) — 411 == 707 seul" do
      facture = create(:facture, organisation: organisation, client: client, date_echeance: 1.day.ago)
      create(:ligne_facture, facture: facture, organisation: organisation, taux_tva: 0, quantite: 1, prix_unitaire_ht: 100)
      facture.reload
      facture.update_columns(statut: "emise", numero: "FAC-FRANCHISE-1", date_emission: Date.current, emise_at: Time.current)

      resultat = described_class.new(organisation: organisation, debut: Date.current, fin: Date.current).call
      lignes = parser_fec(resultat.contenu).select { |l| l["PieceRef"] == "FAC-FRANCHISE-1" }

      expect(lignes.map { |l| l["CompteNum"] }).to contain_exactly("411", "707")
      total_debit = lignes.sum { |l| montant(l["Debit"]) }
      total_credit = lignes.sum { |l| montant(l["Credit"]) }
      expect(total_debit).to eq(total_credit)
    end

    it "utilise l'id du client comme CompAuxNum quand le siret est vide" do
      client_sans_siret = create(:client, organisation: organisation, type: "particulier", siret: nil, raison_sociale: "Client Sans Siret")
      facture = create(:facture, :emise, organisation: organisation, client: client_sans_siret, date_echeance: 1.day.ago)

      resultat = described_class.new(
        organisation: organisation, debut: facture.date_emission - 1, fin: facture.date_emission + 1
      ).call
      ligne_411 = parser_fec(resultat.contenu).find { |l| l["PieceRef"] == facture.numero && l["CompteNum"] == "411" }

      expect(ligne_411["CompAuxNum"]).to eq(client_sans_siret.id)
    end
  end

  describe "#call — avoir" do
    it "produit une écriture MIROIR équilibrée (411 crédit TTC == 707 + 44571 débit)" do
      avoir = create(:avoir, :emise, organisation: organisation, client: client)

      resultat = described_class.new(
        organisation: organisation, debut: avoir.date_emission - 1, fin: avoir.date_emission + 1
      ).call
      lignes = parser_fec(resultat.contenu).select { |l| l["PieceRef"] == avoir.numero }

      ligne_411 = lignes.find { |l| l["CompteNum"] == "411" }
      expect(montant(ligne_411["Credit"])).to eq(BigDecimal(avoir.total_ttc.to_s))
      expect(ligne_411["Debit"]).to eq("0,00")
      expect(ligne_411["EcritureLib"]).to include("Avoir #{avoir.numero}")
      expect(ligne_411["EcritureLib"]).to include("réf facture #{avoir.facture.numero}")

      ligne_707 = lignes.find { |l| l["CompteNum"] == "707" }
      expect(ligne_707["Credit"]).to eq("0,00")
      expect(montant(ligne_707["Debit"])).to be_positive

      total_debit = lignes.sum { |l| montant(l["Debit"]) }
      total_credit = lignes.sum { |l| montant(l["Credit"]) }
      expect(total_debit).to eq(total_credit)
    end
  end

  describe "#call — encaissement" do
    it "espèces (methode_code 10) -> 531/Caisse, journal CA" do
      facture = create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago)
      create(:paiement, :confirme, organisation: organisation, facture: facture,
             methode_code: "10", montant: 120, date_encaissement: Date.current)

      resultat = described_class.new(organisation: organisation, debut: Date.current, fin: Date.current).call
      lignes = parser_fec(resultat.contenu).select { |l| l["EcritureLib"].include?("Encaissement") }

      expect(lignes.map { |l| l["CompteNum"] }).to contain_exactly("531", "411")
      expect(lignes.map { |l| l["JournalCode"] }.uniq).to eq([ "CA" ])
      total_debit = lignes.sum { |l| montant(l["Debit"]) }
      total_credit = lignes.sum { |l| montant(l["Credit"]) }
      expect(total_debit).to eq(total_credit)
    end

    %w[20 48 58 59].each do |code|
      it "moyen dématérialisé (methode_code #{code}) -> 512/Banque, journal BQ" do
        facture = create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago)
        create(:paiement, :confirme, organisation: organisation, facture: facture,
               methode_code: code, montant: 50, date_encaissement: Date.current)

        resultat = described_class.new(organisation: organisation, debut: Date.current, fin: Date.current).call
        lignes = parser_fec(resultat.contenu).select { |l| l["EcritureLib"].include?("Encaissement") }

        expect(lignes.map { |l| l["CompteNum"] }).to contain_exactly("512", "411")
        expect(lignes.map { |l| l["JournalCode"] }.uniq).to eq([ "BQ" ])
      end
    end

    it "n'écrit AUCUNE ligne de TVA à l'encaissement (déjà écrite à la facture, MVP)" do
      facture = create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago)
      create(:paiement, :confirme, organisation: organisation, facture: facture, montant: 120, date_encaissement: Date.current)

      resultat = described_class.new(organisation: organisation, debut: Date.current, fin: Date.current).call
      lignes = parser_fec(resultat.contenu).select { |l| l["EcritureLib"].include?("Encaissement") }

      expect(lignes.map { |l| l["CompteNum"] }).not_to include("44571")
    end
  end

  describe "bornage et exclusions" do
    it "exclut une facture hors de la plage de dates" do
      facture = create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago)

      resultat = described_class.new(
        organisation: organisation, debut: facture.date_emission + 10, fin: facture.date_emission + 20
      ).call

      expect(resultat.contenu).not_to include(facture.numero)
    end

    it "exclut une facture brouillon (aucune écriture produite)" do
      facture = create(:facture, organisation: organisation, client: client, date_echeance: 1.day.ago)
      create(:ligne_facture, facture: facture, organisation: organisation)

      resultat = described_class.new(
        organisation: organisation, debut: 1.year.ago.to_date, fin: 1.year.from_now.to_date
      ).call

      expect(resultat.contenu.split("\n").size).to eq(1) # en-tête seul
    end

    it "exclut un paiement non confirmé (brouillon)" do
      facture = create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago)
      create(:paiement, organisation: organisation, facture: facture, date_encaissement: Date.current)

      resultat = described_class.new(organisation: organisation, debut: Date.current, fin: Date.current).call
      lignes = parser_fec(resultat.contenu)

      expect(lignes.none? { |l| l["EcritureLib"].include?("Encaissement") }).to be(true)
    end

    it "isolation tenant : aucune donnée d'une autre organisation" do
      autre_organisation = create(:organisation)
      autre_client = create(:client, organisation: autre_organisation)
      create(:facture, :emise, organisation: autre_organisation, client: autre_client, date_echeance: 1.day.ago)

      facture = create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago)

      resultat = described_class.new(
        organisation: organisation, debut: 1.year.ago.to_date, fin: 1.year.from_now.to_date
      ).call
      lignes = parser_fec(resultat.contenu)

      expect(lignes.map { |l| l["PieceRef"] }.uniq).to eq([ facture.numero ])
    end
  end

  describe "numérotation et équilibre global" do
    it "numérote les écritures séquentiellement, sans trou" do
      create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago)
      create(:facture, :emise, organisation: organisation,
             client: create(:client, organisation: organisation), date_echeance: 1.day.ago)

      resultat = described_class.new(
        organisation: organisation, debut: 1.year.ago.to_date, fin: 1.year.from_now.to_date
      ).call
      numeros = parser_fec(resultat.contenu).map { |l| l["EcritureNum"].to_i }.uniq.sort

      expect(numeros).to eq((1..numeros.size).to_a)
    end

    it "le fichier ENTIER est équilibré (somme Debit == somme Credit, toutes écritures confondues)" do
      facture = create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago)
      create(:paiement, :confirme, organisation: organisation, facture: facture,
             montant: facture.total_ttc, date_encaissement: Date.current)
      create(:avoir, :emise, organisation: organisation, client: create(:client, organisation: organisation))

      resultat = described_class.new(
        organisation: organisation, debut: 1.year.ago.to_date, fin: 1.year.from_now.to_date
      ).call
      lignes = parser_fec(resultat.contenu)

      total_debit = lignes.sum { |l| montant(l["Debit"]) }
      total_credit = lignes.sum { |l| montant(l["Credit"]) }
      expect(total_debit).to eq(total_credit)
    end
  end

  describe "format DGFiP strict (art. A47 A-1 LPF)" do
    it "en-tête avec les 18 champs, dans l'ordre exact" do
      resultat = described_class.new(organisation: organisation, debut: 1.year.ago.to_date, fin: Date.current).call
      entete = resultat.contenu.split("\n").first.split("\t", -1)

      expect(entete).to eq(%w[
        JournalCode JournalLib EcritureNum EcritureDate CompteNum CompteLib
        CompAuxNum CompAuxLib PieceRef PieceDate EcritureLib Debit Credit
        EcritureLet DateLet ValidDate Montantdevise Idevise
      ])
    end

    it "sépare les 18 champs par une tabulation" do
      facture = create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago)

      resultat = described_class.new(
        organisation: organisation, debut: facture.date_emission - 1, fin: facture.date_emission + 1
      ).call
      ligne = resultat.contenu.split("\n")[1]

      expect(ligne.split("\t", -1).size).to eq(18)
    end

    it "formate les dates en AAAAMMJJ" do
      facture = create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago)

      resultat = described_class.new(
        organisation: organisation, debut: facture.date_emission - 1, fin: facture.date_emission + 1
      ).call
      ligne = parser_fec(resultat.contenu).first

      expect(ligne["EcritureDate"]).to eq(facture.date_emission.strftime("%Y%m%d"))
      expect(ligne["ValidDate"]).to eq(ligne["EcritureDate"])
    end

    it "formate chaque montant avec une virgule décimale et deux décimales, jamais un point" do
      facture = create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago)

      resultat = described_class.new(
        organisation: organisation, debut: facture.date_emission - 1, fin: facture.date_emission + 1
      ).call

      parser_fec(resultat.contenu).each do |ligne|
        expect(ligne["Debit"]).to match(/\A\d+,\d{2}\z/)
        expect(ligne["Credit"]).to match(/\A\d+,\d{2}\z/)
      end
    end

    it "laisse EcritureLet/DateLet/Montantdevise/Idevise vides" do
      facture = create(:facture, :emise, organisation: organisation, client: client, date_echeance: 1.day.ago)

      resultat = described_class.new(
        organisation: organisation, debut: facture.date_emission - 1, fin: facture.date_emission + 1
      ).call

      parser_fec(resultat.contenu).each do |ligne|
        expect(ligne["EcritureLet"]).to eq("")
        expect(ligne["DateLet"]).to eq("")
        expect(ligne["Montantdevise"]).to eq("")
        expect(ligne["Idevise"]).to eq("")
      end
    end

    it "nomme le fichier <SIREN>FEC<fin AAAAMMJJ>.txt" do
      fin = Date.current

      resultat = described_class.new(organisation: organisation, debut: 1.year.ago.to_date, fin: fin).call

      expect(resultat.nom_fichier).to eq("#{organisation.siret[0, 9]}FEC#{fin.strftime('%Y%m%d')}.txt")
    end

    it "n'injecte aucun commentaire d'honnêteté dans le fichier — l'étiquette vit ailleurs" do
      resultat = described_class.new(organisation: organisation, debut: 1.year.ago.to_date, fin: Date.current).call

      expect(resultat.contenu).not_to include("reconstitué")
      expect(resultat.contenu).not_to include("expert-comptable")
    end
  end

  describe "#etiquette" do
    it "reflète le fait_generateur_tva déclaré par l'organisation" do
      organisation.update!(fait_generateur_tva: "debits")
      service = described_class.new(organisation: organisation, debut: Date.current, fin: Date.current)

      expect(service.etiquette).to include("Régime déclaré : debits")
      expect(service.etiquette).to include("ce n'est pas une comptabilité tenue")
      expect(service.etiquette).to include("expert-comptable")
    end
  end

  describe "#call — garde-fou" do
    it "lève une erreur si debut est postérieur à fin" do
      expect {
        described_class.new(organisation: organisation, debut: Date.current, fin: 1.day.ago.to_date).call
      }.to raise_error(ArgumentError)
    end
  end
end
