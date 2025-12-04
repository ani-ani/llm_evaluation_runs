module wildcard_matcher(
  input [3:0][4:0] word0, // Word0 [char3,char2,char1,char0]
  input [3:0][4:0] word1, // Word1 [char3,char2,char1,char0]
  input [3:0][4:0] word2, // Word2 [char3,char2,char1,char0]
  input [3:0][4:0] word3, // Word3 [char3,char2,char1,char0]
  input [3:0][4:0] pattern, // Pattern [char3,char2,char1,char0]
  output reg [2:0] match_count
);

  // Parallel per-character matching with wildcard (5'd26)
  logic [3:0] w0_pos_match;
  logic [3:0] w1_pos_match;
  logic [3:0] w2_pos_match;
  logic [3:0] w3_pos_match;

  assign w0_pos_match[3] = (pattern[3] == 5'd26) | (word0[3] == pattern[3]);
  assign w0_pos_match[2] = (pattern[2] == 5'd26) | (word0[2] == pattern[2]);
  assign w0_pos_match[1] = (pattern[1] == 5'd26) | (word0[1] == pattern[1]);
  assign w0_pos_match[0] = (pattern[0] == 5'd26) | (word0[0] == pattern[0]);

  assign w1_pos_match[3] = (pattern[3] == 5'd26) | (word1[3] == pattern[3]);
  assign w1_pos_match[2] = (pattern[2] == 5'd26) | (word1[2] == pattern[2]);
  assign w1_pos_match[1] = (pattern[1] == 5'd26) | (word1[1] == pattern[1]);
  assign w1_pos_match[0] = (pattern[0] == 5'd26) | (word1[0] == pattern[0]);

  assign w2_pos_match[3] = (pattern[3] == 5'd26) | (word2[3] == pattern[3]);
  assign w2_pos_match[2] = (pattern[2] == 5'd26) | (word2[2] == pattern[2]);
  assign w2_pos_match[1] = (pattern[1] == 5'd26) | (word2[1] == pattern[1]);
  assign w2_pos_match[0] = (pattern[0] == 5'd26) | (word2[0] == pattern[0]);

  assign w3_pos_match[3] = (pattern[3] == 5'd26) | (word3[3] == pattern[3]);
  assign w3_pos_match[2] = (pattern[2] == 5'd26) | (word3[2] == pattern[2]);
  assign w3_pos_match[1] = (pattern[1] == 5'd26) | (word3[1] == pattern[1]);
  assign w3_pos_match[0] = (pattern[0] == 5'd26) | (word3[0] == pattern[0]);

  // Word-level match (all positions must match)
  logic w0_match, w1_match, w2_match, w3_match;
  assign w0_match = &w0_pos_match;
  assign w1_match = &w1_pos_match;
  assign w2_match = &w2_pos_match;
  assign w3_match = &w3_pos_match;

  // Count matching words (0-4)
  wire [2:0] sum = {2'b0, w0_match} + {2'b0, w1_match} + {2'b0, w2_match} + {2'b0, w3_match};
  always_comb begin
    match_count = sum;
  end

endmodule