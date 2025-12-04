module pair_xor_sum(
  input  [7:0]  data_0,
  input  [7:0]  data_1,
  input  [7:0]  data_2,
  input  [7:0]  data_3,
  output [15:0] total_sum
);

  wire [7:0] xor_01 = data_0 ^ data_1;
  wire [7:0] xor_02 = data_0 ^ data_2;
  wire [7:0] xor_03 = data_0 ^ data_3;
  wire [7:0] xor_12 = data_1 ^ data_2;
  wire [7:0] xor_13 = data_1 ^ data_3;
  wire [7:0] xor_23 = data_2 ^ data_3;

  assign total_sum = xor_01 + xor_02 + xor_03 + xor_12 + xor_13 + xor_23;

endmodule