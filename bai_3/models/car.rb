class Car < ApplicationRecord
  extend Enumerize
  
  belongs_to :user
  belongs_to :marker
  belongs_to :shape
  belongs_to :color
  belongs_to :city

  validates :title, :description, :gear, :engine, :year_car, :odo, :price, presence: true

  validates :title, length: { minimum: 6 }
  validates :odo, :price, numericality: { greater_than_or_equal_to: 1 }
  validates :year_car, numericality: {only_integer: true, greater_than: 999, less_than_or_equal_to: 9999 }

  enumerize :made_in, in: Constant::SELECT_MADE_IN, default: :in, scope: true
  enumerize :gear, in: Constant::GEAR, default: :auto, scope: true
end
