class QuantitiesController < ApplicationController
  before_action only: :new do
    find_quantity if params[:id].present?
  end
  before_action :find_quantity, only: [:edit, :update, :reparent, :destroy]

  before_action except: :index do
    raise AccessForbidden unless current_user.at_least(:active)
  end

  def index
    @quantities = current_user.quantities.ordered.includes(:parent, :subquantities)
  end

  def new
    @quantity = current_user.quantities.new(parent: @quantity)
  end

  def create
    @quantity = current_user.quantities.new(quantity_params)
    if @quantity.save
      @before = @quantity.successive
      @ancestors = @quantity.ancestors
      flash.now[:notice] = t('.success', quantity: @quantity)
    else
      flash.now[:alert] = t('.failure')
      render :new
    end
  end

  def edit
  end

  def update
    if @quantity.update(quantity_params.except(:parent_id))
      @ancestors = @quantity.ancestors
      flash.now[:notice] = t('.success', quantity: @quantity)
    else
      flash.now[:alert] = t('.failure')
      render :edit
    end
  end

  def reparent
    permitted = params.require(:quantity).permit(:parent_id)
    @previous_ancestors = @quantity.ancestors

    unless @quantity.update(permitted)
      flash.now[:alert] = t('.failure')
      render_no_content(@quantity) and return
    end

    @ancestors = @quantity.ancestors
    @self_and_progenies = @quantity.with_progenies
    @before = @self_and_progenies.last.successive
  end

  def destroy
    if @quantity.destroy
      flash.now[:notice] = t('.success', quantity: @quantity)
    else
      flash.now[:alert] = t('.failure')
    end
    @ancestors = @quantity.ancestors
  end

  private

  def quantity_params
    params.require(:quantity).permit(Quantity::ATTRIBUTES)
  end

  def find_quantity
    @quantity = current_user.quantities.find_by!(id: params[:id])
  end
end
