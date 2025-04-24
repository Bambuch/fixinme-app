class MeasurementsController < ApplicationController
  before_action :find_quantity, only: [:new]

  def index
    @quantities = current_user.quantities.ordered
  end

  def new
    prev_quantity_ids = params[:readouts]&.map { |r| r[:quantity_id] } || []
    @prev_quantities = current_user.quantities.find(prev_quantity_ids)

    quantities =
      case params[:scope]
      when 'children'
        @quantity.subquantities
      when 'subtree'
        @quantity.progenies
      else
        [@quantity]
      end
    quantities -= @prev_quantities
    @readouts = current_user.readouts.build(quantities.map { |q| { quantity: q } })

    all_quantities = @prev_quantities + quantities
    @closest_ancestor = current_user.quantities
      .common_ancestors(all_quantities.map(&:parent_id)).first
    all_quantities << @closest_ancestor if @closest_ancestor

    @units = current_user.units.ordered
  end

  def create
  end

  def destroy
  end

  private

  def find_quantity
    @quantity = current_user.quantities.find_by!(id: params[:id])
  end
end
