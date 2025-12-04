module text_lowercase_underscore (
  input [127:0] text,
  output reg valid
);
  integer i;
  logic [7:0] byte_vals [0:15];
  logic is_low [0:15];
  logic is_under [0:15];
  logic is_valid_char [0:15];
  int underscore_count;
  int us_pos;

  // Extract bytes (text[127:120] is first character at position 0)
  always_comb begin
    for (i = 0; i < 16; i = i + 1) begin
      byte_vals[i] = text[(15-i)*8 +: 8];
    end
  end

  // Character classification
  always_comb begin
    for (i = 0; i < 16; i = i + 1) begin
      is_low[i]      = (byte_vals[i] >= 8'h61) && (byte_vals[i] <= 8'h7A); // a-z
      is_under[i]    = (byte_vals[i] == 8'h5F);                            // underscore
      is_valid_char[i] = is_low[i] || is_under[i];
    end
  end

  // Validate pattern
  always_comb begin
    // Count underscores and record position
    underscore_count = 0;
    us_pos = -1;
    for (i = 0; i < 16; i = i + 1) begin
      if (is_under[i]) begin
        underscore_count = underscore_count + 1;
        us_pos = i;
      end
    end

    // Default to invalid
    valid = 1'b0;

    // Exactly one underscore, not at ends
    if ((underscore_count == 1) && (us_pos > 0) && (us_pos < 15)) begin
      // All chars must be lowercase or the single underscore
      // (redundant check, but explicit and fast)
      for (i = 0; i < 16; i = i + 1) begin
        if (!is_valid_char[i]) begin
          valid = 1'b0;
          disable valid;
        end
      end
      // If we get here, all chars are valid and there's exactly one underscore
      valid = 1'b1;
    end else begin
      valid = 1'b0;
    end
  end
endmodule