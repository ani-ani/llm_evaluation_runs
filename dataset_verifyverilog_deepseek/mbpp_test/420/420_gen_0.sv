module cube_sum (input [7:0] n, output [31:0] sum);
  wire [8:0] n_plus_1 = {1'b0, n} + 1'b1;
  wire [15:0] temp1 = ({1'b0, n}) * n_plus_1;
  wire [14:0] temp2 = temp1[15:1];
  wire [29:0] temp3 = temp2 * temp2;
  assign sum = temp3 << 3;
endmodule