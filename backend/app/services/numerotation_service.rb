class NumerotationService
  def self.generer!(organisation:, type_document:, date: Date.current)
    new(
      organisation: organisation,
      type_document: type_document,
      date: date
    ).generer!
  end

  def initialize(organisation:, type_document:, date:)
    @organisation = organisation
    @type_document = type_document
    @date = date
    @annee = date.year
  end

  def generer!
    ActiveRecord::Base.transaction do
      verrouiller_sequence!

      numerotation = Numerotation.find_or_create_by!(
        organisation: @organisation,
        type_document: @type_document,
        annee: @annee
      )

      numerotation.lock!

      numerotation.dernier_numero += 1
      numerotation.save!

      numerotation.numero_formate
    end
  end

  private

  def verrouiller_sequence!
    cle = "numerotation:#{@organisation.id}:#{@type_document}:#{@annee}"
    cle_sql = ActiveRecord::Base.connection.quote(cle)

    ActiveRecord::Base.connection.execute(
      "SELECT pg_advisory_xact_lock(hashtext(#{cle_sql})::bigint)"
    )
  end
end
