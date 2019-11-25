class Matrix < ApplicationRecord
  class << self
    def turn_left(matrix)
      return p 'Matrix is invalid, please input an matrix with n from 1 to 1023' if !matrix.length || matrix.length >= 1024
      matrix.transpose.reverse
    end

    # generate matrix n x n
    def generate_matrix(dimension)
      (1..dimension * dimension).each_slice(dimension).to_a
    end
  end
end
