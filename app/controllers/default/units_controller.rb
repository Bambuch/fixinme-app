class Default::UnitsController < ApplicationController
  navigation_tab :units

  before_action :find_unit, only: :export
  before_action :find_unit_default, only: [:import, :destroy]

  before_action only: :import do
    raise AccessForbidden unless current_user.at_least(:active)
  end
  before_action except: [:index, :import] do
    raise AccessForbidden unless current_user.at_least(:admin)
  end

  def index
    @units = current_user.units.defaults_diff.includes(:base, :subunits).ordered
  end

  def import
    if @unit
      @unit.port!(current_user)
      flash.now[:notice] = t('.success', unit: @unit)
    else
      flash.now[:alert] = t('.failure')
    end
  ensure
    run_and_render :index
  end

  def export
    if @unit
      @unit.port!(nil)
      flash.now[:notice] = t('.success', unit: @unit)
    else
      flash.now[:alert] = t('.failure')
    end
  ensure
    run_and_render :index
  end

  def destroy
    if @unit
      @unit.destroy!
      flash.now[:notice] = t('.success', unit: @unit)
    else
      flash.now[:alert] = t('.failure')
    end
  ensure
    run_and_render :index
  end

  private

  def find_unit
    @unit = current_user.units.find_by!(id: params[:id])
  end

  def find_unit_default
    @unit = Unit.find_by!(id: params[:id], user: nil)
  end
end
