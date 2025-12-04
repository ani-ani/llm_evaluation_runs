module tuple_xor(
    input [3:0] tuple1 [0:3],
    input [3:0] tuple2 [0:3],
    output reg [3:0] result [0:3]
);
  assign result[0] = tuple1[0] ^ tuple2[0];
  assign result[1] = tuple1[1] ^ tuple2[1];
  assign result[2] = tuple1[2] ^ tuple2[2];
  assign result[3] = tuple1[3] ^ tuple2[3];
endmodule