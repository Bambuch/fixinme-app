class Unit < ApplicationRecord
  ATTRIBUTES = [:symbol, :description, :multiplier, :base_id]

  belongs_to :user, optional: true
  belongs_to :base, optional: true, class_name: "Unit"
  has_many :subunits, class_name: "Unit", inverse_of: :base, dependent: :restrict_with_error

  validate if: ->{ base.present? } do
    errors.add(:base, :user_mismatch) unless user_id == base.user_id
    errors.add(:base, :self_reference) if id == base_id
    errors.add(:base, :multilevel_nesting) if base.base_id?
  end
  validates :symbol, presence: true, uniqueness: {scope: :user_id},
    length: {maximum: type_for_attribute(:symbol).limit}
  validates :description, length: {maximum: type_for_attribute(:description).limit}
  validates :multiplier, numericality: {equal_to: 1}, unless: :base
  validates :multiplier, numericality: {greater_than: 0, precision: true, scale: true}, if: :base

  scope :defaults, ->{ where(user: nil) }
  scope :defaults_diff, ->{
    actionable_units = Arel::Table.new('actionable_units')
    units = actionable_units.alias('units')
    bases_units = arel_table.alias('bases_units')
    other_units = arel_table.alias('other_units')
    other_bases_units = arel_table.alias('other_bases_units')
    sub_units = arel_table.alias('sub_units')

    # ...existing code...
  }

  scope :ordered, ->{
    left_outer_joins(:base).order(ordering)
  }

  def self.ordering
    [arel_table.coalesce(Arel::Table.new(:bases_units)[:symbol], arel_table[:symbol]),
     arel_table[:base_id].not_eq(nil),
     :multiplier,
     :symbol]
  end

  before_destroy do
    if subunits.exists?
      errors.add(:base, "Cannot delete unit with dependent subunits")
      throw(:abort)
    end
  end

  def to_s
    symbol
  end

  def movable?
    subunits.empty?
  end

  def default?
    user_id.nil?
  end

  # Should only by invoked on Units returned from #defaults_diff which are #portable
  def port!(recipient)
    recipient_base = base && Unit.find_by!(symbol: base.symbol, user: recipient)
    params = slice(ATTRIBUTES - [:symbol, :base_id])
    Unit.find_or_initialize_by(user: recipient, symbol: symbol)
      .update!(base: recipient_base, **params)
  end

  def successive
    units = Unit.arel_table
    lead = Arel::Nodes::NamedFunction.new('LAG', [units[:id]])
    window = Arel::Nodes::Window.new.order(*Unit.ordering)
    lag_id = lead.over(window).as('lag_id')
    Unit.with(
      units: user.units.left_outer_joins(:base).select(units[Arel.star], lag_id)
    ).where(units[:lag_id].eq(id)).first
  end
end
