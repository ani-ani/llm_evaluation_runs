module closest_num(input reg [7:0] N, output reg [7:0] result);
  always_comb result = N - 1'b1;
endmodule