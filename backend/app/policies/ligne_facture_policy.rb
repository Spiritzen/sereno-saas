# frozen_string_literal: true

class LigneFacturePolicy < ApplicationPolicy
  def index?
    peut_lire?
  end

  def show?
    peut_lire? && meme_organisation?
  end

  def create?
    peut_modifier? && meme_organisation? && facture_brouillon?
  end

  def update?
    peut_modifier? && meme_organisation? && facture_brouillon?
  end

  def destroy?
    peut_modifier? && meme_organisation? && facture_brouillon?
  end

  class Scope < Scope
    def resolve
      return scope.none if utilisateur.blank?
      return scope.none if Current.organisation.blank?

      scope.where(organisation_id: Current.organisation.id)
    end
  end

  private

  def peut_lire?
    utilisateur.present? && Current.organisation.present?
  end

  def peut_modifier?
    return false unless peut_lire?

    super_admin? || owner? || comptable?
  end

  def meme_organisation?
    return false if record.blank?
    return false if Current.organisation.blank?

    record.organisation_id == Current.organisation.id
  end

  def facture_brouillon?
    return false unless record.respond_to?(:facture)
    return false if record.facture.blank?

    record.facture.brouillon?
  end
end
