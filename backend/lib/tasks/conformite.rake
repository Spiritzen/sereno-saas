# frozen_string_literal: true

# Gate de conformite EN 16931 (B4 etage 1, partie B) — XSD + Schematron via
# Mustang (KoSIT Validator). Consomme les artefacts DEJA compiles/committes
# dans backend/vendor/facturx_validation_tooling/ (scenario, XSLT Schematron
# compile+patche, codelist) : ce gate ne recompile RIEN (voir la tache
# conformite:compiler_schematron, outil DEV separe, jamais invoquee ici ni
# par la CI).
#
# Usage :
#   bundle exec rails conformite:valider
#
# Variables d'environnement optionnelles :
#   MUSTANG_JAR_PATH  chemin vers le JAR standalone KoSIT Validator (Mustang).
#                      Defaut : backend/tmp/conformite_tools/mustang-validator.jar
#                      (c'est la que le job CI le telecharge). En local,
#                      pointer vers votre propre copie du JAR.
#   JAVA_CMD          commande java a invoquer. Defaut : "java".
#
# Ce que ce gate prouve, a chaque appel :
#   - une facture (380) ET un avoir (381) dessus, EN TVA STANDARD, valident
#     XSD + Schematron EN 16931 -> ACCEPTABLE, 0 failed-assert ;
#   - la MEME chose en FRANCHISE EN BASE DE TVA (art. 293 B du CGI) ;
#   - un artefact volontairement CORROMPU (devise invalide) est bien REJETE
#     -> preuve que le validateur sait encore dire "non" (sinon ce gate ne
#     prouverait plus rien).
#
# Ce gate echoue (exit non-zero) si :
#   - un outil est introuvable (JRE, JAR Mustang, scenario, XSLT, codelist)
#     -> ERREUR D'INFRASTRUCTURE, jamais avalee en succes silencieux ;
#   - un des 4 artefacts valides n'est pas ACCEPTABLE ou a >= 1 failed-assert ;
#   - l'auto-test negatif N'EST PAS rejete.
#
# Hors perimetre (etage 2 / hors scenario existant) : veraPDF (PDF/A-3b),
# France CTC / BR-FR (aucun scenario Mustang France n'existe a ce jour).

require "fileutils"
require "open3"
require "timeout"
require "tmpdir"
require "nokogiri"

module ConformiteGate
  # Erreur d'infrastructure : outil absent, JVM inutilisable, timeout, sortie
  # illisible. Toujours distincte d'un echec de regle metier -- jamais un
  # "pass" silencieux (cf. §3.E du prompt B4 etage 1 partie B).
  class InfraError < StandardError; end

  # Localise et invoque Mustang. Aucune logique de regle ici -- uniquement
  # de la plomberie processus, avec les deux contournements Windows constates
  # au spike B4 etage 0 :
  #   - stdin redirige depuis un VRAI fichier (jamais /dev/null, jamais un
  #     pipe) : sous Windows, Validator#isPiped plante
  #     (java.io.IOException: Fonction incorrecte / FileInputStream#available)
  #     des que stdin est un pipe -- y compris via Open3 sans "in:" explicite ;
  #   - chemins TOUJOURS absolus (Rails.root.join en produit nativement) : un
  #     segment relatif dans -r fait echouer la resolution d'URI interne de
  #     Mustang ("is not within the configured repository").
  class Outillage
    DUREE_MAX_PROCESSUS = 120 # secondes, par invocation Mustang

    attr_reader :java_cmd, :mustang_jar, :scenario, :repository

    def initialize
      @java_cmd = ENV.fetch("JAVA_CMD", "java")
      @mustang_jar = Pathname.new(
        ENV.fetch("MUSTANG_JAR_PATH", Rails.root.join("tmp", "conformite_tools", "mustang-validator.jar").to_s)
      )
      @scenario = Rails.root.join("vendor", "facturx_validation_tooling", "scenarios.xml")
      @repository = Rails.root
      @dummy_stdin = Rails.root.join("tmp", "conformite_tools", "dummy_stdin.txt")
    end

    def verifier!
      unless mustang_jar.exist?
        raise InfraError, "JAR Mustang introuvable : #{mustang_jar} (definir MUSTANG_JAR_PATH ?)"
      end

      raise InfraError, "Scenario Mustang introuvable : #{scenario}" unless scenario.exist?

      _out, err, status = Open3.capture3(java_cmd, "-version")
      raise InfraError, "JRE/JDK introuvable ou inutilisable (#{java_cmd} -version a echoue) : #{err}" unless status.success?

      FileUtils.mkdir_p(@dummy_stdin.dirname)
      FileUtils.touch(@dummy_stdin) unless @dummy_stdin.exist?
    end

    # Retourne [stdout, stderr, status].
    def executer_mustang(fichiers:, dossier_sortie:)
      FileUtils.mkdir_p(dossier_sortie)

      commande = [
        java_cmd, "-jar", mustang_jar.to_s,
        "-s", scenario.to_s,
        "-r", repository.to_s,
        "-p",
        "-o", dossier_sortie.to_s,
        *fichiers.map(&:to_s)
      ]

      Timeout.timeout(DUREE_MAX_PROCESSUS) do
        Open3.capture3(*commande, in: @dummy_stdin.to_s)
      end
    rescue Timeout::Error
      raise InfraError, "Mustang n'a pas repondu en #{DUREE_MAX_PROCESSUS}s (fichiers : #{fichiers.join(', ')})"
    end
  end

  # Lecture d'un rapport Mustang (createReportInput) pour UN artefact.
  # Lecture seule -- ne juge rien au-dela de ce que Mustang a deja constate.
  class RapportMustang
    def self.pour(fichier, dossier_sortie)
      chemin = dossier_sortie.join("#{fichier.basename('.xml')}-report.xml")
      return nil unless chemin.exist?

      new(chemin)
    end

    def initialize(chemin)
      @doc = Nokogiri::XML(File.read(chemin))
    end

    def asserts_echouees
      @doc.xpath("//*[local-name()='failed-assert']").map do |noeud|
        {
          id: noeud["id"],
          message: noeud.xpath(".//*[local-name()='text']").text.strip
        }
      end
    end

    def conforme?
      asserts_echouees.empty?
    end

    def regles_declenchees
      @doc.xpath("//*[local-name()='fired-rule']").map { |n| n["context"] }.compact.uniq
    end
  end

  # Orchestre : emission des 4 artefacts (standard/franchise x 380/381),
  # validation Mustang, auto-test negatif, gate. Toute donnee est produite
  # dans une transaction PostgreSQL explicitement annulee (jamais persistee).
  class Runner
    def initialize
      @outillage = Outillage.new
      @scratch = Rails.root.join("tmp", "conformite_gate")
      @problemes = []
    end

    def call
      puts "== Gate de conformite EN 16931 (XSD + Schematron, via Mustang) =="
      @outillage.verifier!
      puts "Outillage OK : java=#{@outillage.java_cmd} ; mustang_jar=#{@outillage.mustang_jar}"

      FileUtils.rm_rf(@scratch)
      FileUtils.mkdir_p(@scratch)

      artefacts = { standard: emettre_paire(regime: :standard), franchise: emettre_paire(regime: :franchise) }

      valider_artefacts_conformes(artefacts)
      comparer_regles_standard_vs_franchise(artefacts)
      valider_auto_test_negatif(artefacts.fetch(:standard).fetch(:facture))

      if @problemes.empty?
        puts
        puts "== GATE VERT : 4 artefacts ACCEPTABLE + 0 failed-assert ; auto-test negatif bien REJECT =="
        0
      else
        puts
        puts "== GATE ROUGE =="
        @problemes.each { |p| puts "  - #{p}" }
        1
      end
    rescue InfraError => e
      puts
      puts "== ERREUR INFRASTRUCTURE (PAS un echec de regle metier) : #{e.message} =="
      1
    ensure
      FileUtils.rm_rf(@scratch)
    end

    private

    def emettre_paire(regime:)
      resultat = nil

      ActiveRecord::Base.transaction do
        organisation = FactoryBot.create(:organisation)
        client = FactoryBot.create(:client, organisation: organisation)
        utilisateur = FactoryBot.create(:utilisateur, organisation: organisation)

        taux_tva = regime == :franchise ? 0 : 20
        organisation.update_columns(regime_tva: "franchise", numero_tva: nil) if regime == :franchise

        facture = FactoryBot.create(:facture, organisation: organisation, client: client)
        FactoryBot.create(:ligne_facture, facture: facture, organisation: organisation, taux_tva: taux_tva)
        facture_emise = FactureEmissionService.new(facture: facture, utilisateur: utilisateur).call
        facture_emise.reload

        avoir = FactoryBot.create(:avoir, organisation: organisation, client: client, facture: facture_emise)
        FactoryBot.create(:ligne_avoir, avoir: avoir, organisation: organisation, quantite: 1, prix_unitaire_ht: 50, taux_tva: taux_tva)
        avoir_emis = AvoirEmissionService.new(avoir: avoir, utilisateur: utilisateur).call
        avoir_emis.reload

        dossier = @scratch.join(regime.to_s)
        FileUtils.mkdir_p(dossier)

        # Noms de fichiers PREFIXES par le regime, volontairement : Mustang
        # ecrit ses rapports (-o) en se basant UNIQUEMENT sur le nom de
        # fichier, sans le sous-dossier. Deux artefacts nommes a l'identique
        # (ex. "380-facture.xml" dans standard/ ET franchise/) ecrasent le
        # meme rapport de sortie en cas de validation groupee -- collision
        # silencieuse constatee en dur pendant la mise au point de ce gate
        # (la "franchise" validait alors, sans le dire, le rapport du
        # "standard" ecrit apres elle). Des noms globalement uniques rendent
        # la collision structurellement impossible.
        chemin_facture = dossier.join("#{regime}-380-facture.xml")
        chemin_avoir = dossier.join("#{regime}-381-avoir.xml")
        FileUtils.cp(Rails.root.join(facture_emise.xml_url), chemin_facture)
        FileUtils.cp(Rails.root.join(avoir_emis.xml_url), chemin_avoir)

        # Nettoyage du stockage cree par l'emission reelle (storage/<env>/...,
        # jamais storage/development/ en pratique puisque ce gate tourne en
        # RAILS_ENV=test) : on ne laisse aucun residu de scratch en plus de
        # la transaction annulee.
        FileUtils.rm_rf(Rails.root.join("storage", Rails.env, "factures", facture_emise.id.to_s))
        FileUtils.rm_rf(Rails.root.join("storage", Rails.env, "avoirs", avoir_emis.id.to_s))

        resultat = {
          facture: chemin_facture,
          avoir: chemin_avoir,
          facture_numero: facture_emise.numero,
          avoir_numero: avoir_emis.numero
        }

        raise ActiveRecord::Rollback
      end

      resultat
    end

    def valider_artefacts_conformes(artefacts)
      fichiers = artefacts.values.flat_map { |paire| [ paire[:facture], paire[:avoir] ] }
      dossier_sortie = @scratch.join("rapports-valides")

      @outillage.executer_mustang(fichiers: fichiers, dossier_sortie: dossier_sortie)

      fichiers.each do |fichier|
        rapport = RapportMustang.pour(fichier, dossier_sortie)

        if rapport.nil?
          @problemes << "#{fichier} : aucun rapport Mustang genere -- verdict indetermine, traite comme un echec"
        elsif rapport.conforme?
          puts "  OK  #{fichier.relative_path_from(@scratch)} : ACCEPTABLE, 0 failed-assert"
        else
          details = rapport.asserts_echouees.map { |a| "[#{a[:id]}] #{a[:message]}" }.join(" | ")
          @problemes << "#{fichier} : #{rapport.asserts_echouees.size} failed-assert(s) -- #{details}"
        end
      end
    end

    def comparer_regles_standard_vs_franchise(artefacts)
      dossier_sortie = @scratch.join("rapports-valides")
      rapport_standard = RapportMustang.pour(artefacts.dig(:standard, :facture), dossier_sortie)
      rapport_franchise = RapportMustang.pour(artefacts.dig(:franchise, :facture), dossier_sortie)
      return if rapport_standard.nil? || rapport_franchise.nil?

      regles_std = rapport_standard.regles_declenchees
      regles_fra = rapport_franchise.regles_declenchees

      puts
      puts "  Regles declenchees uniquement en FRANCHISE (absentes du standard) :"
      (regles_fra - regles_std).each { |r| puts "    + #{r}" }
      puts "  Regles declenchees uniquement en STANDARD (absentes de la franchise) :"
      (regles_std - regles_fra).each { |r| puts "    + #{r}" }
    end

    def valider_auto_test_negatif(facture_standard_valide)
      contenu = File.read(facture_standard_valide)
      pattern = %r{<ram:InvoiceCurrencyCode>[^<]*</ram:InvoiceCurrencyCode>}
      contenu_corrompu = contenu.sub(pattern, "<ram:InvoiceCurrencyCode>ZZZ</ram:InvoiceCurrencyCode>")

      if contenu_corrompu == contenu
        @problemes << "AUTO-TEST NEGATIF : balise InvoiceCurrencyCode introuvable, corruption impossible -- negatif non tente"
        return
      end

      corrompu = @scratch.join("corrompu.xml")
      File.write(corrompu, contenu_corrompu)

      dossier_sortie = @scratch.join("rapport-negatif")
      _out, _err, status = @outillage.executer_mustang(fichiers: [ corrompu ], dossier_sortie: dossier_sortie)
      rapport = RapportMustang.pour(corrompu, dossier_sortie)

      if status.success? || rapport.nil? || rapport.conforme?
        @problemes << "AUTO-TEST NEGATIF EN ECHEC : le document corrompu (devise invalide) n'a PAS ete rejete " \
                      "-- le validateur ne sait plus dire non, ce gate ne prouve plus rien"
      else
        ids = rapport.asserts_echouees.map { |a| a[:id] }.join(", ")
        puts "  OK  auto-test negatif : document corrompu bien REJECT (#{rapport.asserts_echouees.size} failed-assert : #{ids})"
      end
    end
  end

  # [DEV UNIQUEMENT -- jamais invoque par le gate ni par la CI]
  # Recompile Factur-X_1.09_EN16931-compiled.xsl a partir d'une COPIE de
  # travail du .sch GELE (jamais l'original) + du squelette PATCHE deja
  # committe + Saxon-HE. A relancer uniquement si le squelette lui-meme
  # evolue (le .sch gele, lui, ne changera jamais).
  class CompilateurSchematron
    def initialize
      @saxon_jar = Pathname.new(ENV.fetch("SAXON_JAR_PATH", Rails.root.join("tmp", "conformite_tools", "saxon-he.jar").to_s))
      @xmlresolver_jar = Pathname.new(ENV.fetch("XMLRESOLVER_JAR_PATH", Rails.root.join("tmp", "conformite_tools", "xmlresolver.jar").to_s))
      @squelette = Rails.root.join(
        "vendor", "facturx_validation_tooling", "schematron_en16931", "skeleton", "iso_svrl_for_xslt2_sereno_id_fix.xsl"
      )
      @sch_gele = Rails.root.join("vendor", "facturx", "schematron", "en16931", "Factur-X_1.09_EN16931.sch")
      @sortie = Rails.root.join(
        "vendor", "facturx_validation_tooling", "schematron_en16931", "Factur-X_1.09_EN16931-compiled.xsl"
      )
    end

    def call
      [ @saxon_jar, @xmlresolver_jar ].each do |jar|
        next if jar.exist?

        raise InfraError,
              "JAR requis introuvable : #{jar} (Saxon-HE 13.0 + org.xmlresolver:xmlresolver:6.0.23 -- " \
              "voir backend/vendor/facturx_validation_tooling/README.md pour les sources officielles)"
      end
      raise InfraError, "Schematron gele introuvable : #{@sch_gele}" unless @sch_gele.exist?

      Dir.mktmpdir do |dossier_travail|
        copie_sch = Pathname.new(dossier_travail).join("Factur-X_1.09_EN16931.sch")
        FileUtils.cp(@sch_gele, copie_sch) # copie de travail -- l'original gele n'est jamais touche

        dummy_stdin = Pathname.new(dossier_travail).join("dummy_stdin.txt")
        FileUtils.touch(dummy_stdin)

        commande = [
          "java", "-cp", [ @saxon_jar, @xmlresolver_jar ].join(File::PATH_SEPARATOR), "net.sf.saxon.Transform",
          "-s:#{copie_sch}",
          "-xsl:#{@squelette}",
          "-o:#{@sortie}"
        ]

        _out, err, status = Open3.capture3(*commande, in: dummy_stdin.to_s)
        raise InfraError, "Echec de compilation Saxon : #{err}" unless status.success?
      end

      puts "Recompile : #{@sortie}"
      puts "Relancer `bundle exec rails conformite:valider` puis relire le diff avant de commiter."
    end
  end
end

namespace :conformite do
  desc "Gate EN16931 (XSD+Schematron via Mustang) : facture+avoir, standard+franchise, auto-test negatif. Exit non-zero si echec (B4)."
  task valider: :environment do
    exit_code = ConformiteGate::Runner.new.call
    exit(exit_code)
  end

  desc "[DEV UNIQUEMENT, PAS dans le gate CI] Recompile le Schematron EN16931 (XSLT) depuis le .sch gele + squelette patche."
  task compiler_schematron: :environment do
    ConformiteGate::CompilateurSchematron.new.call
  end
end
