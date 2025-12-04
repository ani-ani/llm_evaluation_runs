module max_word_length(
  input [3:0] word0_len,
  input [3:0] word1_len,
  input [3:0] word2_len,
  input [3:0] word3_len,
  output logic [3:0] max_length
);
  assign max_length = ((word0_len >= word1_len) ? ((word0_len >= word2_len) ? ((word0_len >= word3_len) ? word0_len : word3_len) : ((word2_len >= word3_len) ? word2_len : word3_len)) : ((word1_len >= word2_len) ? ((word1_len >= word3_len) ? word1_len : word3_len) : ((word2_len >= word3_len) ? word2_len : word3_len)));
endmodule