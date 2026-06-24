# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :utilisateur, :record

  def initialize(utilisateur, record)
    @utilisateur = utilisateur
    @record = record
  end

  # --- Helpers rôles ---

  def super_admin?
    utilisateur.role == "super_admin"
  end

  def owner?
    utilisateur.role == "owner"
  end

  def comptable?
    utilisateur.role == "comptable"
  end

  def membre?
    utilisateur.role == "membre"
  end

  def gestionnaire?
    owner? || super_admin?
  end

  # --- Actions par défaut : tout interdit, surcharger dans chaque policy ---

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  # --- Scope de base ---

  class Scope
    def initialize(utilisateur, scope)
      @utilisateur = utilisateur
      @scope = scope
    end

    def resolve
      raise NotImplementedError,
            "#{self.class}#resolve doit être implémenté dans chaque policy."
    end

    private

    attr_reader :utilisateur, :scope
  end
end
