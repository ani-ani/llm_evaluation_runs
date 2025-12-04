module rear_extract (
  input [7:0] tuple0_e0, tuple0_e1, tuple0_e2,
  input [7:0] tuple1_e0, tuple1_e1, tuple1_e2,
  input [7:0] tuple2_e0, tuple2_e1, tuple2_e2,
  output [7:0] out0, out1, out2
);
  assign out0 = tuple0_e2;
  assign out1 = tuple1_e2;
  assign out2 = tuple2_e2;
endmodule