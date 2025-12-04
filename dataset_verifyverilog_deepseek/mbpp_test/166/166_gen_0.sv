module even_xor_pairs_counter (
  input [7:0] a0, a1, a2, a3, a4, a5, a6, a7,
  output [4:0] count
);
  wire [7:0] bits = {a0[0], a1[0], a2[0], a3[0], a4[0], a5[0], a6[0], a7[0]};
  wire [3:0] odd_count = bits[0] + bits[1] + bits[2] + bits[3] + bits[4] + bits[5] + bits[6] + bits[7];
  wire [3:0] even_count = 4'd8 - odd_count;
  wire [4:0] even_pairs = (even_count * (even_count - 4'd1)) >> 1;
  wire [4:0] odd_pairs = (odd_count * (odd_count - 4'd1)) >> 1;
  assign count = even_pairs + odd_pairs;
endmodule