# frozen_string_literal: true

# Gate de conformite EN 16931 + PDF/A-3b (B4 etage 1 partie B + etage 2) —
# XSD + Schematron via Mustang (KoSIT Validator), et PDF/A-3b via veraPDF.
# Consomme les artefacts DEJA compiles/committes dans
# backend/vendor/facturx_validation_tooling/ (scenario, XSLT Schematron
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
#   VERAPDF_JAR_PATH  chemin vers le JAR autonome veraPDF CLI
#                      (org.verapdf.apps:cli, classifie "jar-with-dependencies"
#                      publie sans classifier distinct sur Maven Central).
#                      Defaut : backend/tmp/conformite_tools/verapdf-cli.jar
#   JAVA_CMD          commande java a invoquer. Defaut : "java".
#
# Ce que ce gate prouve, a chaque appel :
#   - une facture (380) ET un avoir (381) dessus, EN TVA STANDARD, valident
#     XSD + Schematron EN 16931 -> ACCEPTABLE, 0 failed-assert ;
#   - la MEME chose en FRANCHISE EN BASE DE TVA (art. 293 B du CGI) ;
#   - les 4 PDF correspondants sont conformes PDF/A-3b (veraPDF, profil "3b") ;
#   - un artefact XML volontairement CORROMPU (devise invalide) est REJETE
#     par Mustang, ET un PDF volontairement NON-PDF/A est REJETE par veraPDF
#     -> preuve que les DEUX validateurs savent encore dire "non" (sinon ce
#     gate ne prouverait plus rien).
#
# Ce gate echoue (exit non-zero) si :
#   - un outil est introuvable (JRE, JAR Mustang, JAR veraPDF, scenario,
#     XSLT, codelist) -> ERREUR D'INFRASTRUCTURE, jamais avalee en succes
#     silencieux ;
#   - un des 4 artefacts XML valides n'est pas ACCEPTABLE ou a >= 1
#     failed-assert ;
#   - un des 4 PDF valides n'est pas conforme PDF/A-3b ;
#   - l'un des deux auto-tests negatifs (XML ou PDF) N'EST PAS rejete.
#
# Hors perimetre : France CTC / BR-FR (aucun scenario Mustang France
# n'existe a ce jour -- dette tracee, pas de solution de contournement).

require "fileutils"
require "open3"
require "timeout"
require "tmpdir"
require "nokogiri"
require "hexapdf"

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
    DUREE_MAX_PROCESSUS = 120 # secondes, par invocation (Mustang ou veraPDF)
    PROFIL_PDFA = "3b"

    attr_reader :java_cmd, :mustang_jar, :verapdf_jar, :scenario, :repository

    def initialize
      @java_cmd = ENV.fetch("JAVA_CMD", "java")
      @mustang_jar = Pathname.new(
        ENV.fetch("MUSTANG_JAR_PATH", Rails.root.join("tmp", "conformite_tools", "mustang-validator.jar").to_s)
      )
      @verapdf_jar = Pathname.new(
        ENV.fetch("VERAPDF_JAR_PATH", Rails.root.join("tmp", "conformite_tools", "verapdf-cli.jar").to_s)
      )
      @scenario = Rails.root.join("vendor", "facturx_validation_tooling", "scenarios.xml")
      @repository = Rails.root
      @dummy_stdin = Rails.root.join("tmp", "conformite_tools", "dummy_stdin.txt")
    end

    def verifier!
      unless mustang_jar.exist?
        raise InfraError, "JAR Mustang introuvable : #{mustang_jar} (definir MUSTANG_JAR_PATH ?)"
      end

      unless verapdf_jar.exist?
        raise InfraError, "JAR veraPDF introuvable : #{verapdf_jar} (definir VERAPDF_JAR_PATH ?)"
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

    # Retourne [stdout (rapport XML veraPDF), stderr, status]. Un seul appel
    # peut valider plusieurs PDF -- le rapport contient un <job> par fichier,
    # identifie par son chemin complet (cf RapportVeraPdf). Contrairement a
    # Mustang, veraPDF n'a pas presente le bug isPiped au spike/etage 2 : le
    # dummy stdin est neanmoins reutilise par coherence et innocuite.
    def executer_verapdf(fichiers:)
      commande = [
        java_cmd, "-jar", verapdf_jar.to_s,
        "-f", PROFIL_PDFA,
        *fichiers.map(&:to_s)
      ]

      Timeout.timeout(DUREE_MAX_PROCESSUS) do
        Open3.capture3(*commande, in: @dummy_stdin.to_s)
      end
    rescue Timeout::Error
      raise InfraError, "veraPDF n'a pas repondu en #{DUREE_MAX_PROCESSUS}s (fichiers : #{fichiers.join(', ')})"
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

  # Lecture d'un rapport veraPDF (XML sur stdout) pour retrouver le resultat
  # d'UN artefact PDF parmi ceux valides en un seul appel. Lecture seule.
  class RapportVeraPdf
    def initialize(sortie_xml)
      @doc = Nokogiri::XML(sortie_xml)
    end

    # Retrouve le <job> dont <name> se termine par le nom du fichier -- le
    # rapport veraPDF imprime le chemin complet tel que passe en argument
    # (avec les separateurs de l'OS), comparer sur le basename evite toute
    # ambiguite de format de chemin.
    def pour(fichier)
      nom = fichier.basename.to_s
      job = @doc.xpath("//job").find { |j| j.at_xpath(".//name")&.text.to_s.end_with?(nom) }
      return nil if job.nil?

      Resultat.new(job.at_xpath(".//validationReport"))
    end

    class Resultat
      def initialize(noeud_validation_report)
        @noeud = noeud_validation_report
      end

      def conforme?
        @noeud && @noeud["isCompliant"] == "true"
      end

      def regles_echouees
        return [] if @noeud.nil?

        @noeud.xpath(".//rule[@status='failed']").map do |regle|
          {
            specification: regle["specification"],
            clause: regle["clause"],
            message: regle.at_xpath(".//check/errorMessage")&.text
          }
        end
      end
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
      puts "== Gate de conformite EN 16931 + PDF/A-3b (XSD+Schematron via Mustang, PDF/A-3b via veraPDF) =="
      @outillage.verifier!
      puts "Outillage OK : java=#{@outillage.java_cmd} ; mustang_jar=#{@outillage.mustang_jar} ; verapdf_jar=#{@outillage.verapdf_jar}"

      FileUtils.rm_rf(@scratch)
      FileUtils.mkdir_p(@scratch)

      artefacts = { standard: emettre_paire(regime: :standard), franchise: emettre_paire(regime: :franchise) }

      valider_artefacts_conformes(artefacts)
      comparer_regles_standard_vs_franchise(artefacts)
      valider_auto_test_negatif(artefacts.fetch(:standard).fetch(:facture))

      valider_pdfs_conformes(artefacts)
      valider_auto_test_negatif_pdf

      if @problemes.empty?
        puts
        puts "== GATE VERT : 4 XML ACCEPTABLE + 0 failed-assert ; 4 PDF conformes PDF/A-3b ; " \
             "les deux auto-tests negatifs (XML et PDF) bien REJECT =="
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
        chemin_facture_pdf = dossier.join("#{regime}-380-facture.pdf")
        chemin_avoir_pdf = dossier.join("#{regime}-381-avoir.pdf")
        FileUtils.cp(Rails.root.join(facture_emise.xml_url), chemin_facture)
        FileUtils.cp(Rails.root.join(avoir_emis.xml_url), chemin_avoir)
        FileUtils.cp(Rails.root.join(facture_emise.pdf_url), chemin_facture_pdf)
        FileUtils.cp(Rails.root.join(avoir_emis.pdf_url), chemin_avoir_pdf)

        # Nettoyage du stockage cree par l'emission reelle (storage/<env>/...,
        # jamais storage/development/ en pratique puisque ce gate tourne en
        # RAILS_ENV=test) : on ne laisse aucun residu de scratch en plus de
        # la transaction annulee.
        FileUtils.rm_rf(Rails.root.join("storage", Rails.env, "factures", facture_emise.id.to_s))
        FileUtils.rm_rf(Rails.root.join("storage", Rails.env, "avoirs", avoir_emis.id.to_s))

        resultat = {
          facture: chemin_facture,
          avoir: chemin_avoir,
          facture_pdf: chemin_facture_pdf,
          avoir_pdf: chemin_avoir_pdf,
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

    # B4 etage 2 : PDF/A-3b des 4 memes artefacts, via veraPDF. Le 380 est
    # attendu conforme (deja verifie manuellement au gel du socle) ; le 381
    # (avoir, avec filigrane) ne l'avait JAMAIS ete -- c'est le point que cet
    # etage tranche.
    def valider_pdfs_conformes(artefacts)
      fichiers = artefacts.values.flat_map { |paire| [ paire[:facture_pdf], paire[:avoir_pdf] ] }

      stdout, _err, _status = @outillage.executer_verapdf(fichiers: fichiers)
      rapport = RapportVeraPdf.new(stdout)

      fichiers.each do |fichier|
        resultat = rapport.pour(fichier)

        if resultat.nil?
          @problemes << "#{fichier} : aucun resultat veraPDF retrouve dans le rapport -- verdict indetermine, traite comme un echec"
        elsif resultat.conforme?
          puts "  OK  #{fichier.relative_path_from(@scratch)} : PDF/A-3b conforme"
        else
          details = resultat.regles_echouees.map { |r| "[#{r[:specification]} #{r[:clause]}] #{r[:message]}" }.join(" | ")
          @problemes << "#{fichier} : PDF/A-3b NON conforme -- #{details}"
        end
      end
    end

    # AUTO-TEST NEGATIF PDF (obligatoire, cf. auto-test negatif XML) : un PDF
    # bare, sans aucun marqueur PDF/A (pas d'OutputIntent, pas de metadonnees
    # XMP), genere via HexaPDF -- la meme bibliotheque et la meme technique
    # que le script de mise au point historique de FacturXPackageService
    # (backend/tmp/*, jamais committe). DOIT etre REJECTED ; sinon veraPDF ne
    # sait plus dire non et ce gate ne prouve plus rien pour le PDF/A-3b.
    def valider_auto_test_negatif_pdf
      document = HexaPDF::Document.new
      document.pages.add
      pdf_non_conforme = @scratch.join("pdf-non-conforme.pdf")
      document.write(pdf_non_conforme.to_s)

      stdout, _err, status = @outillage.executer_verapdf(fichiers: [ pdf_non_conforme ])
      resultat = RapportVeraPdf.new(stdout).pour(pdf_non_conforme)

      if status.success? || resultat.nil? || resultat.conforme?
        @problemes << "AUTO-TEST NEGATIF PDF EN ECHEC : un PDF sans aucun marqueur PDF/A n'a PAS ete rejete " \
                      "-- veraPDF ne sait plus dire non, ce gate ne prouve plus rien pour le PDF/A-3b"
      else
        puts "  OK  auto-test negatif PDF : document sans marqueur PDF/A bien REJECTED " \
             "(#{resultat.regles_echouees.size} regle(s) echouee(s))"
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
  desc "Gate EN16931+PDF/A-3b (Mustang+veraPDF) : facture+avoir, standard+franchise, 2 auto-tests negatifs. Exit non-zero si echec (B4)."
  task valider: :environment do
    exit_code = ConformiteGate::Runner.new.call
    exit(exit_code)
  end

  desc "[DEV UNIQUEMENT, PAS dans le gate CI] Recompile le Schematron EN16931 (XSLT) depuis le .sch gele + squelette patche."
  task compiler_schematron: :environment do
    ConformiteGate::CompilateurSchematron.new.call
  end
end
