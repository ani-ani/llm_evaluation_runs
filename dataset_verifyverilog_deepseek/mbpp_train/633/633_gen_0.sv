module pair_xor_sum(
  input [7:0] data_0,
  input [7:0] data_1,
  input [7:0] data_2,
  input [7:0] data_3,
  output [15:0] total_sum
);
  
  wire [7:0] pair01 = data_0 ^ data_1;
  wire [7:0] pair02 = data_0 ^ data_2;
  wire [7:0] pair03 = data_0 ^ data_3;
  wire [7:0] pair12 = data_1 ^ data_2;
  wire [7:0] pair13 = data_1 ^ data_3;
  wire [7:0] pair23 = data_2 ^ data_3;
  
  assign total_sum = pair01 + pair02 + pair03 + pair12 + pair13 + pair23;
  
endmodule