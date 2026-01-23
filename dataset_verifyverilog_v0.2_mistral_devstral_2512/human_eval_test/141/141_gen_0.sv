module file_name_check (
  input [127:0] file_name,
  output reg is_valid
);

  reg [3:0] digit_count = 0;
  reg [3:0] dot_count = 0;
  reg [7:0] dot_pos = 8'hFF;
  reg [7:0] i;
  reg [7:0] char;
  reg [7:0] prefix_len;
  reg [7:0] suffix_len;
  reg [23:0] suffix = 0;
  reg [7:0] suffix_index = 0;
  reg valid_prefix = 1'b0;
  reg valid_suffix = 1'b0;

  // Iterate through each byte in file_name
  for (i = 0; i < 16; i = i + 1) begin
    char = file_name[(i+1)*8 - 1 : i*8];

    // Check for null terminator (end of string)
    if (char == 8'h00) begin
      break;
    end

    // Count digits
    if (char >= 8'h30 && char <= 8'h39) begin
      digit_count = digit_count + 1;
    end

    // Count dots and record position
    if (char == 8'h2E) begin
      dot_count = dot_count + 1;
      if (dot_pos == 8'hFF) begin
        dot_pos = i;
      end
    end
  end

  // Check digit count
  if (digit_count > 3) begin
    is_valid = 1'b0;
    return;
  end

  // Check dot count
  if (dot_count != 1) begin
    is_valid = 1'b0;
    return;
  end

  // Check prefix
  prefix_len = dot_pos;
  if (prefix_len == 0) begin
    is_valid = 1'b0;
    return;
  end

  // Check first character is a letter
  char = file_name[7:0];
  if (!((char >= 8'h41 && char <= 8'h5A) || (char >= 8'h61 && char <= 8'h7A))) begin
    is_valid = 1'b0;
    return;
  end

  // Check suffix
  suffix_len = 16 - dot_pos - 1;
  if (suffix_len != 3) begin
    is_valid = 1'b0;
    return;
  end

  // Extract suffix
  for (i = dot_pos + 1; i < dot_pos + 4; i = i + 1) begin
    char = file_name[(i+1)*8 - 1 : i*8];
    suffix[(suffix_index + 1)*8 - 1 : suffix_index*8] = char;
    suffix_index = suffix_index + 1;
  end

  // Compare suffix with valid options
  if (suffix == 24'h747874 || suffix == 24'h657865 || suffix == 24'h646C6C) begin
    valid_suffix = 1'b1;
  end

  is_valid = valid_suffix;

endmodule