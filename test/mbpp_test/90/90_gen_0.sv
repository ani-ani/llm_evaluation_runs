module max_word_length(
  input  [3:0] word0_len,
  input  [3:0] word1_len,
  input  [3:0] word2_len,
  input  [3:0] word3_len,
  output [3:0] max_length
);

  wire [3:0] max01;
  wire [3:0] max23;

  assign max01 = (word0_len >= word1_len) ? word0_len : word1_len;
  assign max23 = (word2_len >= word3_len) ? word2_len : word3_len;
  assign max_length = (max01 >= max23) ? max01 : max23;

endmodule