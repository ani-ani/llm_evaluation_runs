module divisible_tuples (
  input [7:0] K,
  input [7:0] tuple0_0, tuple0_1, tuple0_2,
  input [7:0] tuple1_0, tuple1_1, tuple1_2,
  input [7:0] tuple2_0, tuple2_1, tuple2_2,
  input [7:0] tuple3_0, tuple3_1, tuple3_2,
  output [3:0] valid_tuples
);

  wire bit0 = (K != 8'h0) && ((tuple0_0 % K) == 8'h0) && ((tuple0_1 % K) == 8'h0) && ((tuple0_2 % K) == 8'h0);
  wire bit1 = (K != 8'h0) && ((tuple1_0 % K) == 8'h0) && ((tuple1_1 % K) == 8'h0) && ((tuple1_2 % K) == 8'h0);
  wire bit2 = (K != 8'h0) && ((tuple2_0 % K) == 8'h0) && ((tuple2_1 % K) == 8'h0) && ((tuple2_2 % K) == 8'h0);
  wire bit3 = (K != 8'h0) && ((tuple3_0 % K) == 8'h0) && ((tuple3_1 % K) == 8'h0) && ((tuple3_2 % K) == 8'h0);
  assign valid_tuples = {bit3, bit2, bit1, bit0};

endmodule