module find_p_words (
  input [127:0] str_input,  // Big-endian: str_input[127:120] = first character
  output reg [63:0] word1,  // First word (8 bytes), zero-padded if shorter
  output reg [63:0] word2,  // Second word (8 bytes), zero-padded if shorter
  output reg valid          // 1 if both words start with 'P' (0x50) and space exists
);

  // Helper: extract byte at a given index (0 = MSB, 15 = LSB)
  function [7:0] byte_at (input [3:0] idx, input [127:0] s);
    byte_at = s[127 - idx*8 -: 8];
  endfunction

  integer i;
  reg [3:0] space_idx;      // 0..15; 4 = index of space, if found
  reg space_exists;

  always @(*) begin
    // Defaults
    word1 = 64'h0;
    word2 = 64'h0;
    space_exists = 1'b0;
    space_idx = 4'd16;      // sentinel for "not found"

    // Find first space (0x20) scanning from the left (MSB side)
    for (i = 0; i < 16; i = i + 1) begin
      if (byte_at(i, str_input) == 8'h20) begin
        space_exists = 1'b1;
        space_idx = i[3:0];
        break;
      end
    end

    // If a space was found, split into two 8-byte chunks using bytes (indexes 0..15)
    if (space_exists) begin
      for (i = 0; i < 8; i = i + 1) begin
        // Word1 uses bytes immediately before the space (i=0 -> byte0 -> MSB of word1)
        if (space_idx > i) begin
          word1[63 - i*8 -: 8] = byte_at(i, str_input);
        end else begin
          word1[63 - i*8 -: 8] = 8'h0;
        end

        // Word2 uses the 8 bytes immediately after the space
        if ((space_idx + 4'd1 + i) < 16) begin
          word2[63 - i*8 -: 8] = byte_at(space_idx + 4'd1 + i, str_input);
        end else begin
          word2[63 - i*8 -: 8] = 8'h0;
        end
      end

      // Case-sensitive check: both words must start with 'P' (0x50) at the MSB position
      // Also require that a space exists (already ensured above)
      valid = (byte_at(0, str_input) == 8'h50) && (byte_at(space_idx + 4'd1, str_input) == 8'h50);
    end else begin
      // No space -> invalid
      valid = 1'b0;
    end
  end

endmodule
