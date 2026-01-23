module count_distinct_characters (
  input [127:0] char_array,
  input [3:0] length,
  output reg [3:0] distinct_count
);

  integer i, j;
  reg [7:0] normalized_chars [0:15];
  reg [15:0] distinct_flags;

  // Normalize characters (convert lowercase to uppercase)
  for (i = 0; i < 16; i = i + 1) begin
    if (i < length) begin
      if (char_array[(i+1)*8-1 : i*8] >= 8'h61 && char_array[(i+1)*8-1 : i*8] <= 8'h7A) begin
        normalized_chars[i] = char_array[(i+1)*8-1 : i*8] - 8'h20;
      end else begin
        normalized_chars[i] = char_array[(i+1)*8-1 : i*8];
      end
    end else begin
      normalized_chars[i] = 8'h00;
    end
  end

  // Initialize distinct flags
  distinct_flags = 16'h0000;

  // Check for distinct characters
  for (i = 0; i < length; i = i + 1) begin
    reg is_distinct = 1'b1;
    for (j = 0; j < i; j = j + 1) begin
      if (normalized_chars[i] == normalized_chars[j]) begin
        is_distinct = 1'b0;
      end
    end
    distinct_flags[i] = is_distinct;
  end

  // Count distinct characters
  distinct_count = 0;
  for (i = 0; i < 16; i = i + 1) begin
    if (distinct_flags[i]) begin
      distinct_count = distinct_count + 1;
    end
  end

endmodule