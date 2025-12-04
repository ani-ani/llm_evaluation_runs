module max_word_length(
  input [3:0] word0_len,
  input [3:0] word1_len,
  input [3:0] word2_len,
  input [3:0] word3_len,
  output logic [3:0] max_length
);
  
  wire [3:0] stage0_max = (word0_len > word1_len) ? word0_len : word1_len;
  wire [3:0] stage1_max = (word2_len > word3_len) ? word2_len : word3_len;
  
  always_comb begin
    max_length = (stage0_max > stage1_max) ? stage0_max : stage1_max;
  end
endmodule