module odd_length_sum(input [7:0] arr_0, arr_1, arr_2, arr_3, output reg [7:0] sum);
  always_comb begin
    sum = (((1 * (4 - 0) + 1) / 2) * arr_0) +
          (((2 * (4 - 1) + 1) / 2) * arr_1) +
          (((3 * (4 - 2) + 1) / 2) * arr_2) +
          (((4 * (4 - 3) + 1) / 2) * arr_3);
  end
endmodule