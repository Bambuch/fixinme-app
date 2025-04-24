class UnitsController < ApplicationController
  before_action only: :new do
    find_unit if params[:id].present?
  end
  before_action :find_unit, only: [:edit, :update, :rebase, :destroy]

  before_action except: :index do
    raise AccessForbidden unless current_user.at_least(:active)
  end

  def index
    @units = current_user.units.ordered.includes(:base, :subunits)
  end

  def new
    @unit = current_user.units.new(base: @unit)
  end

  def create
    @unit = current_user.units.new(unit_params)
    if @unit.save
      @before = @unit.successive
      flash.now[:notice] = t('.success', unit: @unit)
    else
      flash.now[:alert] = t('.failure')
      render :new
    end
  end

  def edit
  end

  def update
    if @unit.update(unit_params.except(:base_id))
      flash.now[:notice] = t('.success', unit: @unit)
    else
      flash.now[:alert] = t('.failure')
      render :edit
    end
  end

  def rebase
    permitted = params.require(:unit).permit(:base_id)
    permitted.merge!(multiplier: 1) if permitted[:base_id].blank? && @unit.multiplier != 1

    @previous_base = @unit.base
    if @unit.update(permitted)
      @before = @unit.successive
      if @unit.multiplier_previously_changed?
        flash.now[:notice] = t(".multiplier_reset", unit: @unit)
      end
    else
      flash.now[:alert] = t('.failure')
      render_no_content(@unit)
    end
  end

  def destroy
    if @unit.destroy
      flash.now[:notice] = t('.success', unit: @unit)
    else
      flash.now[:alert] = t('.failure')
    end
  end

  private

  def unit_params
    params.require(:unit).permit(Unit::ATTRIBUTES)
  end

  def find_unit
    @unit = current_user.units.find_by!(id: params[:id])
  end
end
