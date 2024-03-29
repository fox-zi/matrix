require 'rails_helper'

RSpec.describe Matrix, type: :model do
  describe 'matrix test function turn left 90' do

    context 'turn left 90 case success' do

      [1, 2, 100, 500, 1023].each do |dimension|
        matrix_input = Matrix.generate_matrix(dimension)
        matrix_result = Matrix.turn_left(matrix_input)

        it "check matrix turn left 90 with n = #{dimension} value" do
          matrix_input.each_with_index do |row, row_i|
            row.each_with_index do |_, col_i|
              expect(matrix_result[dimension - 1 - col_i][row_i]).to eq(matrix_input[row_i][col_i])
            end
          end
        end

        it "check matrix turn left 90 with n = #{dimension} type" do
          expect(matrix_result.class.should(eq Array))
        end

      end
    end

    context 'turn left 90 case failures' do

      [0, 1024].each do |dimension|
        let(:matrix_input) { Matrix.generate_matrix(dimension) }
        let(:matrix_result) { Matrix.turn_left(matrix_input) }

        it "check matrix turn left 90 with n = #{dimension} value" do
          expect(matrix_result).to eq('Matrix is invalid, please input an matrix with n from 1 to 1023')
        end

        it "check matrix turn left 90 with n = #{dimension} type" do
          expect(matrix_result.class.should(eq String))
        end

      end
    end
  end
end
