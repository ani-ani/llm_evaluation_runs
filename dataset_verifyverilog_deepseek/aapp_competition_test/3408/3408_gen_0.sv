module wildcard_matcher(
  input [3:0][4:0] word0,
  input [3:0][4:0] word1,
  input [3:0][4:0] word2,
  input [3:0][4:0] word3,
  input [3:0][4:0] pattern,
  output reg [2:0] match_count
);

  wire word0_match = ( (pattern[0] == 5'd26) || (word0[0] == pattern[0]) )
                  && ( (pattern[1] == 5'd26) || (word0[1] == pattern[1]) )
                  && ( (pattern[2] == 5'd26) || (word0[2] == pattern[2]) )
                  && ( (pattern[3] == 5'd26) || (word0[3] == pattern[3]) );

  wire word1_match = ( (pattern[0] == 5'd26) || (word1[0] == pattern[0]) )
                  && ( (pattern[1] == 5'd26) || (word1[1] == pattern[1]) )
                  && ( (pattern[2] == 5'd26) || (word1[2] == pattern[2]) )
                  && ( (pattern[3] == 5'd26) || (word1[3] == pattern[3]) );

  wire word2_match = ( (pattern[0] == 5'd26) || (word2[0] == pattern[0]) )
                  && ( (pattern[1] == 5'd26) || (word2[1] == pattern[1]) )
                  && ( (pattern[2] == 5'd26) || (word2[2] == pattern[2]) )
                  && ( (pattern[3] == 5'd26) || (word2[3] == pattern[3]) );

  wire word3_match = ( (pattern[0] == 5'd26) || (word3[0] == pattern[0]) )
                  && ( (pattern[1] == 5'd26) || (word3[1] == pattern[1]) )
                  && ( (pattern[2] == 5'd26) || (word3[2] == pattern[2]) )
                  && ( (pattern[3] == 5'd26) || (word3[3] == pattern[3]) );

  always_comb begin
    match_count = word0_match + word1_match + word2_match + word3_match;
  end

endmodule