class Marker < ApplicationRecord
  validates :title, presence: true
  has_many :cars
end
