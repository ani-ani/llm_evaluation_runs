module cycpattern_check(
  input [63:0] a,
  input [63:0] b,
  input [3:0] len_a,
  input [3:0] len_b,
  output result
);

  wire [7:0] a_bytes [0:7];
  wire [7:0] b_bytes [0:7];
  wire [7:0] rotated_b [0:7];
  wire [7:0] a_substring [0:7];
  wire match;
  wire [7:0] rotation;
  wire [7:0] pos;
  wire [7:0] i;
  wire [7:0] j;
  wire [7:0] k;

  // Extract bytes from a and b (little-endian)
  genvar g;
  generate
    for (g = 0; g < 8; g = g + 1) begin : extract_bytes
      assign a_bytes[g] = a[8*g + 7 : 8*g];
      assign b_bytes[g] = b[8*g + 7 : 8*g];
    end
  endgenerate

  // Check all rotations and positions
  assign match = 0;
  for (rotation = 0; rotation < 8; rotation = rotation + 1) begin
    if (rotation < len_b) begin
      // Generate rotated string
      for (i = 0; i < 8; i = i + 1) begin
        if (i < len_b) begin
          assign rotated_b[i] = b_bytes[(i + rotation) % len_b];
        end else begin
          assign rotated_b[i] = 8'h0;
        end
      end

      // Check all possible positions in a
      for (pos = 0; pos <= len_a - len_b; pos = pos + 1) begin
        // Extract substring from a
        for (j = 0; j < 8; j = j + 1) begin
          if (j < len_b) begin
            assign a_substring[j] = a_bytes[pos + j];
          end else begin
            assign a_substring[j] = 8'h0;
          end
        end

        // Compare rotated_b and a_substring
        for (k = 0; k < 8; k = k + 1) begin
          if (k < len_b) begin
            if (rotated_b[k] != a_substring[k]) begin
              assign match = match | 0;
            end else begin
              assign match = match | (k == len_b - 1);
            end
          end
        end
      end
    end
  end

  assign result = match;

endmodule