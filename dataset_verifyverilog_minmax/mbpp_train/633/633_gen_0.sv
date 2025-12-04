module pair_xor_sum(
  input  [7:0] data_0,
  input  [7:0] data_1,
  input  [7:0] data_2,
  input  [7:0] data_3,
  output [15:0] total_sum
);
  wire [7:0] x01 = data_0 ^ data_1;
  wire [7:0] x02 = data_0 ^ data_2;
  wire [7:0] x03 = data_0 ^ data_3;
  wire [7:0] x12 = data_1 ^ data_2;
  wire [7:0] x13 = data_1 ^ data_3;
  wire [7:0] x23 = data_2 ^ data_3;
  assign total_sum = {8'h0, x01} + {8'h0, x02} + {8'h0, x03} + {8'h0, x12} + {8'h0, x13} + {8'h0, x23};
endmodule
