module wildcard_matcher(
  input [3:0][4:0] word0, // Word0 [char3,char2,char1,char0]
  input [3:0][4:0] word1, // Word1 [char3,char2,char1,char0]
  input [3:0][4:0] word2, // Word2 [char3,char2,char1,char0]
  input [3:0][4:0] word3, // Word3 [char3,char2,char1,char0]
  input [3:0][4:0] pattern, // Pattern [char3,char2,char1,char0]
  output reg [2:0] match_count
);

  wire [3:0] is_wildcard;
  wire [3:0] w0_match_char;
  wire [3:0] w1_match_char;
  wire [3:0] w2_match_char;
  wire [3:0] w3_match_char;
  wire w0_match;
  wire w1_match;
  wire w2_match;
  wire w3_match;

  assign is_wildcard[0] = (pattern[0] == 5'd26);
  assign is_wildcard[1] = (pattern[1] == 5'd26);
  assign is_wildcard[2] = (pattern[2] == 5'd26);
  assign is_wildcard[3] = (pattern[3] == 5'd26);

  assign w0_match_char[0] = is_wildcard[0] | (word0[0] == pattern[0]);
  assign w0_match_char[1] = is_wildcard[1] | (word0[1] == pattern[1]);
  assign w0_match_char[2] = is_wildcard[2] | (word0[2] == pattern[2]);
  assign w0_match_char[3] = is_wildcard[3] | (word0[3] == pattern[3]);
  assign w0_match = &w0_match_char;

  assign w1_match_char[0] = is_wildcard[0] | (word1[0] == pattern[0]);
  assign w1_match_char[1] = is_wildcard[1] | (word1[1] == pattern[1]);
  assign w1_match_char[2] = is_wildcard[2] | (word1[2] == pattern[2]);
  assign w1_match_char[3] = is_wildcard[3] | (word1[3] == pattern[3]);
  assign w1_match = &w1_match_char;

  assign w2_match_char[0] = is_wildcard[0] | (word2[0] == pattern[0]);
  assign w2_match_char[1] = is_wildcard[1] | (word2[1] == pattern[1]);
  assign w2_match_char[2] = is_wildcard[2] | (word2[2] == pattern[2]);
  assign w2_match_char[3] = is_wildcard[3] | (word2[3] == pattern[3]);
  assign w2_match = &w2_match_char;

  assign w3_match_char[0] = is_wildcard[0] | (word3[0] == pattern[0]);
  assign w3_match_char[1] = is_wildcard[1] | (word3[1] == pattern[1]);
  assign w3_match_char[2] = is_wildcard[2] | (word3[2] == pattern[2]);
  assign w3_match_char[3] = is_wildcard[3] | (word3[3] == pattern[3]);
  assign w3_match = &w3_match_char;

  always @* begin
    match_count = w0_match + w1_match + w2_match + w3_match;
  end

endmodule