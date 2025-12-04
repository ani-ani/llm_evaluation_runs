module find_p_words(
  input  [127:0] str_input,
  output reg [63:0] word1,
  output reg [63:0] word2,
  output reg        valid
);

  integer i;
  integer space_index;       // Byte index of first space (0..15), -1 if none
  reg [7:0] bytes [0:15];    // Byte array, bytes[0] = first char (MSB)

  always @* begin
    // Unpack input into bytes (big-endian)
    for (i = 0; i < 16; i = i + 1) begin
      bytes[i] = str_input[127 - 8*i -: 8];
    end

    // Find first space (0x20)
    space_index = -1;
    for (i = 0; i < 16; i = i + 1) begin
      if (space_index == -1 && bytes[i] == 8'h20)
        space_index = i;
    end

    // Default outputs
    word1 = 64'h0;
    word2 = 64'h0;
    valid = 1'b0;

    // Proceed only if a space exists and it is not the first or last byte
    if (space_index > 0 && space_index < 15) begin
      integer w1_len;
      integer w2_start;
      integer w2_len;
      integer j;

      // First word: bytes[0 .. space_index-1], up to 8 bytes
      w1_len = (space_index > 8) ? 8 : space_index;
      for (j = 0; j < w1_len; j = j + 1) begin
        word1[63 - 8*j -: 8] = bytes[j];
      end
      for (j = w1_len; j < 8; j = j + 1) begin
        word1[63 - 8*j -: 8] = 8'h00;
      end

      // Second word: starts at byte after space_index
      w2_start = space_index + 1;
      if (w2_start < 16) begin
        w2_len = 16 - w2_start;
        if (w2_len > 8) w2_len = 8;

        for (j = 0; j < w2_len; j = j + 1) begin
          word2[63 - 8*j -: 8] = bytes[w2_start + j];
        end
        for (j = w2_len; j < 8; j = j + 1) begin
          word2[63 - 8*j -: 8] = 8'h00;
      end

        // valid if both words start with 'P' (0x50) and space exists
        if (word1[63:56] == 8'h50 && word2[63:56] == 8'h50)
          valid = 1'b1;
      end
    end
  end

endmodule