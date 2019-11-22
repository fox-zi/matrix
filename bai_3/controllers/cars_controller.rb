class CarsController < ApplicationController
  before_action :authenticate_user!

  def new
    @car = Car.new
  end

  def create
    @car = Car.new car_params
    @car.user = current_user
    return redirect_to(car_path(@car)), notice: 'Car registed' if @car.save
    render :new
  end

  def show
    @car = Car.find_by(id: params[:id])
  end

  private

  def car_params
    params.require(:car).permit(:title, :price, :made_in, :gear, :shape_id, :marker_id, :city_id,
                                :color_id, :shape_id, :odo, :year_car, :engine, :description)
  end

end
