module filter_by_prefix (
  input [63:0] strings [0:7],
  input [63:0] prefix,
  input [2:0] prefix_len,
  output [63:0] matches [0:7],
  output [2:0] match_count
);

  integer i, j;
  reg [63:0] matches_reg [0:7];
  reg [2:0] match_count_reg;
  reg match_flags [0:7];

  // Initialize outputs
  for (i = 0; i < 8; i = i + 1) begin
    matches_reg[i] = 64'b0;
    match_flags[i] = 1'b0;
  end
  match_count_reg = 3'b0;

  // Check each string for prefix match
  for (i = 0; i < 8; i = i + 1) begin
    reg [7:0] match = 1'b1;
    
    // Compare each character in prefix
    for (j = 0; j < prefix_len; j = j + 1) begin
      reg [7:0] string_char = strings[i][(7 - j) * 8 +: 8];
      reg [7:0] prefix_char = prefix[(7 - j) * 8 +: 8];
      
      if (string_char != prefix_char) begin
        match = 1'b0;
      end
    end
    
    match_flags[i] = match;
  end

  // Count matches and populate output array
  integer match_index = 0;
  for (i = 0; i < 8; i = i + 1) begin
    if (match_flags[i]) begin
      matches_reg[match_index] = strings[i];
      match_index = match_index + 1;
    end
  end
  match_count_reg = match_index;

  // Assign outputs
  for (i = 0; i < 8; i = i + 1) begin
    matches[i] = matches_reg[i];
  end
  match_count = match_count_reg;

endmodule