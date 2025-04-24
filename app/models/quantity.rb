class Quantity < ApplicationRecord
  ATTRIBUTES = [:name, :description, :parent_id]
  attr_cached :depth, :pathname

  belongs_to :user, optional: true
  belongs_to :parent, optional: true, class_name: "Quantity"
  has_many :subquantities, ->{ order(:name) }, class_name: "Quantity",
    inverse_of: :parent, dependent: :restrict_with_error

  validate if: ->{ parent.present? } do
    errors.add(:parent, :user_mismatch) unless user_id == parent.user_id
    errors.add(:parent, :self_reference) if id == parent_id
  end
  validate if: ->{ parent.present? }, on: :update do
    errors.add(:parent, :descendant_reference) if ancestor_of?(parent)
  end
  validates :name, presence: true, uniqueness: {scope: [:user_id, :parent_id]},
    length: {maximum: type_for_attribute(:name).limit}
  validates :description, length: {maximum: type_for_attribute(:description).limit}

  # Update `depth`s of progenies after parent change
  after_update if: :depth_previously_changed? do
    quantities = Quantity.arel_table
    selected = Arel::Table.new('selected')

    self.class.connection.update(
      Arel::UpdateManager.new.table(
        Arel::Nodes::JoinSource.new(
          quantities,
          [
            quantities.create_join(
              # TODO: use .with(quantities: user.quantities) once the '?' problem is fixed
              Quantity.with_recursive(selected: [
                quantities.project(quantities[:id], quantities[:depth])
                  .where(quantities[:id].eq(id).and(quantities[:user_id].eq(user.id))),
                quantities.project(quantities[:id], selected[:depth] + 1)
                  .join(selected).on(selected[:id].eq(quantities[:parent_id]))
              ]).select(selected[Arel.star]).from(selected).arel.as('selected'),
              quantities.create_on(quantities[:id].eq(selected[:id]))
            )
          ]
        )
      ).set(quantities[:depth] => selected[:depth]),
      "#{self.class} Update All"
    )
  end

  after_update if: -> { name_previously_changed? || parent_previously_changed? } do
    quantities = Quantity.arel_table
    selected = Arel::Table.new('selected')

    # Add :name/:parent setters and update self :pathname there
    Quantity.with_recursive(selected: [
      quantities.project(quantities[:id].as('quantity_id'), quantities[:pathname])
        .where(quantities[:id].eq(id)),
      quantities.project(
        quantities[:id],
        selected[:pathname].concat(Arel::Nodes.build_quoted(' → '))
          .concat(quantities[:name])
      ).join(selected).on(selected[:quantity_id].eq(quantities[:parent_id]))
    ]).joins(:selected).update_all(pathname: selected[:pathname])
  end

  def parent=(value)
    super
    self[:depth] = parent&.depth&.succ || 0
  end

  def parent_id=(value)
    super
    self[:depth] = value.nil? ? 0 : parent&.depth&.succ || 0
  end

  scope :defaults, ->{ where(user: nil) }

  # Return: ordered [sub]hierarchy
  scope :ordered, ->(root: nil, include_root: true) {
    numbered = Arel::Table.new('numbered')

    self.model.with(numbered: numbered(:parent_id, :name)).with_recursive(arel_table.name => [
      numbered.project(
        numbered[Arel.star],
        numbered.cast(numbered[:child_number], 'BINARY').as('path')
      ).where(numbered[root && include_root ? :id : :parent_id].eq(root)),
      numbered.project(
        numbered[Arel.star],
        arel_table[:path].concat(numbered[:child_number])
      ).join(arel_table).on(numbered[:parent_id].eq(arel_table[:id]))
    ]).order(arel_table[:path])
  }

  # TODO: extract named functions to custom Arel extension
  # NOTE: once recursive queries allow use of window functions, this scope can
  # be merged with :ordered
  # https://gist.github.com/ProGM/c6df08da14708dcc28b5ca325df37ceb#extending-arel
  scope :numbered, ->(parent_column, order_column) {
    select(
      arel_table[Arel.star],
      Arel::Nodes::NamedFunction.new(
        'LPAD',
        [
          Arel::Nodes::NamedFunction.new('ROW_NUMBER', [])
            .over(Arel::Nodes::Window.new.partition(parent_column).order(order_column)),
          Arel::SelectManager.new.project(
            Arel::Nodes::NamedFunction.new('LENGTH', [Arel.star.count])
          ).from(arel_table),
          Arel::Nodes.build_quoted('0')
        ],
      ).as('child_number')
    )
  }

  def to_s
    name
  end

  def destroyable?
    subquantities.empty?
  end

  def default?
    parent_id.nil?
  end

  # Common ancestors, assuming node is a descendant of itself
  scope :common_ancestors, ->(of) {
    selected = Arel::Table.new('selected')

    # Take unique IDs, so self can be called with parent nodes of collection to
    # get common ancestors of collection _excluding_ nodes in collection.
    uniq_of = of.uniq
    model.with(selected: self).with_recursive(arel_table.name => [
      selected.project(selected[Arel.star]).where(selected[:id].in(uniq_of)),
      selected.project(selected[Arel.star])
        .join(arel_table).on(selected[:id].eq(arel_table[:parent_id]))
    ]).select(arel_table[Arel.star])
      .group(column_names)
      .having(arel_table[:id].count.eq(uniq_of.size))
      .order(arel_table[:depth].desc)
  }

  # Return: successive record in order of appearance; used for partial view reload
  def successive
    quantities = Quantity.arel_table
    Quantity.with(
      quantities: user.quantities.ordered.select(
        quantities[Arel.star],
        Arel::Nodes::NamedFunction.new('LAG', [quantities[:id]]).over.as('lag_id')
      )
    ).where(quantities[:lag_id].eq(id)).first
  end

  def with_progenies
    user.quantities.ordered(root: id).to_a
  end

  def progenies
    user.quantities.ordered(root: id, include_root: false).to_a
  end

  # Return: record with ID `of` with its ancestors, sorted by `depth`
  scope :with_ancestors, ->(of) {
    selected = Arel::Table.new('selected')

    model.with(selected: self).with_recursive(arel_table.name => [
      selected.project(selected[Arel.star]).where(selected[:id].eq(of)),
      selected.project(selected[Arel.star])
        .join(arel_table).on(selected[:id].eq(arel_table[:parent_id]))
    ])
  }

  # Return: ancestors of (possibly destroyed) self
  def ancestors
    user.quantities.with_ancestors(parent_id).order(:depth).to_a
  end

  def ancestor_of?(progeny)
    user.quantities.with_ancestors(progeny.id).exists?(id)
  end
end
